package com.adidev.valtsky.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import android.text.InputType
import android.util.Log
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.content.res.ColorStateList
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import com.adidev.valtsky.R
import com.adidev.valtsky.data.*
import com.adidev.valtsky.data.db.AppDatabase
import com.adidev.valtsky.data.db.MediaItem
import com.adidev.valtsky.databinding.ActivityMainBinding
import androidx.lifecycle.lifecycleScope
import com.adidev.valtsky.service.PhotoMonitorService
import com.adidev.valtsky.telegram.TelegramApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.adidev.valtsky.util.ThemeHelper
import java.text.SimpleDateFormat
import java.util.*
import com.google.android.material.tabs.TabLayout

class MainActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "MainActivity"
    }

    private lateinit var binding: ActivityMainBinding
    private var breathingAnimator: ObjectAnimator? = null
    private var failedAdapter: FailedItemsAdapter? = null
    private var isFailedExpanded: Boolean = false
    private var isManualSharingInProgress: Boolean = false
    private var currentFailedList: List<MediaItem> = emptyList()

    private fun setupGuideTabs() {
        val tabs = binding.guideView.guideTabs
        val scrollSetUp = binding.guideView.scrollSetUp
        val scrollPermissions = binding.guideView.scrollPermissions
        val scrollPrecautions = binding.guideView.scrollPrecautions

        tabs.addOnTabSelectedListener(object : TabLayout.OnTabSelectedListener {
            override fun onTabSelected(tab: TabLayout.Tab?) {
                when (tab?.position) {
                    0 -> {
                        scrollSetUp.visibility = View.VISIBLE
                        scrollPermissions.visibility = View.GONE
                        scrollPrecautions.visibility = View.GONE
                    }
                    1 -> {
                        scrollSetUp.visibility = View.GONE
                        scrollPermissions.visibility = View.VISIBLE
                        scrollPrecautions.visibility = View.GONE
                    }
                    2 -> {
                        scrollSetUp.visibility = View.GONE
                        scrollPermissions.visibility = View.GONE
                        scrollPrecautions.visibility = View.VISIBLE
                    }
                }
            }
            override fun onTabUnselected(tab: TabLayout.Tab?) {}
            override fun onTabReselected(tab: TabLayout.Tab?) {}
        })
    }

    private fun setupDrawer() {
        binding.btnMenu.setOnClickListener {
            binding.drawerLayout.openDrawer(androidx.core.view.GravityCompat.START)
        }

        binding.navigationView.setNavigationItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> {
                    binding.homeView.visibility = View.VISIBLE
                    binding.guideView.root.visibility = View.GONE
                }
                R.id.nav_guide -> {
                    binding.homeView.visibility = View.GONE
                    binding.guideView.root.visibility = View.VISIBLE
                }
            }
            binding.drawerLayout.closeDrawers()
            true
        }
    }

    private fun onThemeToggleClicked() {
        val next = when (this.selectedTheme) {
            Prefs.ThemeChoice.LIGHT -> Prefs.ThemeChoice.DARK
            Prefs.ThemeChoice.DARK -> Prefs.ThemeChoice.LIGHT
        }
        this.selectedTheme = next
        recreate()
    }

    private fun onRefreshClicked() {
        if (!this.monitoringEnabled) {
            showToast("Start monitoring first to refresh.")
            return
        }

        binding.btnRefresh.animate()
            .rotationBy(360f)
            .setDuration(500)
            .start()
        
        val intent = Intent(this, PhotoMonitorService::class.java).apply {
            action = PhotoMonitorService.ACTION_REFRESH
        }
        startService(intent)
        showToast("Refreshing library and resuming sync...")
    }

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        val galleryGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            results[Manifest.permission.READ_MEDIA_IMAGES] == true &&
            results[Manifest.permission.READ_MEDIA_VIDEO] == true
        } else {
            results[Manifest.permission.READ_EXTERNAL_STORAGE] == true
        }

        if (galleryGranted) {
            startMonitoringService()
        } else {
            showToast("Gallery permissions are required to detect new media.")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        ThemeHelper.applyTheme(this)
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        // Requirement Step 1: Safety net check for channel change
        val currentChannel = this.channelId
        val lastSavedChannel = this.savedChannelId
        if (currentChannel.isNotBlank() && currentChannel != lastSavedChannel) {
            Log.i(TAG, "Channel change detected on launch. Resetting sync state.")
            this.lastSyncedTs = System.currentTimeMillis()
            this.savedChannelId = currentChannel
        }

        // Deep Reset: Crash Recovery
        if (this.resetInProgress) {
            Log.w(TAG, "Incomplete reset detected. Re-running deep reset...")
            performDeepReset()
        }

        setupDrawer()
        restoreFields()
        setupRecyclerView()
        updateUi()
        checkBatteryOptimisation()
        observeData()
        setupGuideTabs()
        
        binding.btnThemeToggle.setOnClickListener { onThemeToggleClicked() }
        binding.btnRefresh.setOnClickListener { onRefreshClicked() }
        binding.btnClearFailed.setOnClickListener {
            lifecycleScope.launch(Dispatchers.IO) {
                AppDatabase.getInstance(this@MainActivity).mediaDao().clearFailed()
            }
            isFailedExpanded = false
            updateFailedAdapterList()
        }

        binding.btnFailedMore.setOnClickListener {
            val isCurrentlyCollapsed = !isFailedExpanded
            val newText = if (isCurrentlyCollapsed) {
                getString(R.string.failed_less)
            } else {
                val totalCount = failedAdapter?.itemCount ?: 0
                getString(R.string.failed_more, totalCount - 3)
            }

            binding.btnFailedMore.animate().alpha(0f).setDuration(100).withEndAction {
                binding.btnFailedMore.text = newText
                binding.btnFailedMore.animate().alpha(1f).setDuration(100).start()
            }.start()

            binding.rvFailedItems.post {
                isFailedExpanded = !isFailedExpanded
                updateFailedAdapterList()
            }
        }

        binding.btnUploadManually.setOnClickListener {
            onUploadManuallyClicked()
        }

        binding.btnToggle.setOnClickListener { view -> animateButtonPress(view); onToggleClicked() }
        binding.btnValidate.setOnClickListener { view -> animateButtonPress(view); onValidateClicked() }
        binding.btnBatteryFix.setOnClickListener { view -> animateButtonPress(view); openBatterySettings() }
        binding.btnLock.setOnClickListener { view -> animateButtonPress(view); onLockClicked() }
        binding.btnReset.setOnClickListener { view -> animateButtonPress(view); onResetClicked() }
        binding.btnRetryFailed.setOnClickListener { view ->
            animateButtonPress(view)
            view.animate()
                .rotationBy(360f)
                .setDuration(500)
                .setInterpolator(AccelerateDecelerateInterpolator())
                .start()
            onRetryFailedClicked() 
        }

        binding.rgNetwork.setOnCheckedChangeListener { _, checkedId ->
            this@MainActivity.uploadNetworkType = when (checkedId) {
                R.id.rbWifi -> Prefs.NetworkTypeChoice.WIFI
                R.id.rbMobile -> Prefs.NetworkTypeChoice.MOBILE
                else -> Prefs.NetworkTypeChoice.BOTH
            }
            // Trigger sync to re-check network allowance
            val intent = Intent(this, PhotoMonitorService::class.java).apply {
                action = PhotoMonitorService.ACTION_RETRY
            }
            startService(intent)
        }

        binding.btnShowToken.setOnClickListener {
            val isHidden = binding.etBotToken.inputType ==
                    (InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD)
            if (isHidden) {
                binding.etBotToken.inputType =
                    InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                binding.btnShowToken.text = getString(R.string.btn_hide)
            } else {
                binding.etBotToken.inputType =
                    InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                binding.btnShowToken.text = getString(R.string.btn_show)
            }
            binding.etBotToken.setSelection(binding.etBotToken.text.length)
        }

        binding.btnPauseUpload.setOnClickListener {
            animateButtonPress(it)
            onPauseUploadClicked()
        }
    }

    private fun setupRecyclerView() {
        failedAdapter = FailedItemsAdapter { item ->
            lifecycleScope.launch(Dispatchers.IO) {
                AppDatabase.getInstance(this@MainActivity).mediaDao().retrySingle(item.filePath)
            }
            val intent = Intent(this, PhotoMonitorService::class.java).apply {
                action = PhotoMonitorService.ACTION_RETRY
            }
            startService(intent)
        }
        binding.rvFailedItems.apply {
            layoutManager = LinearLayoutManager(this@MainActivity)
            adapter = failedAdapter
            itemAnimator?.apply {
                addDuration = 220
                removeDuration = 180
                moveDuration = 200
                changeDuration = 150
            }
        }
    }

    override fun onResume() {
        super.onResume()
        updateUi()
        checkBatteryOptimisation()
        startBreathingAnimation()
    }

    override fun onPause() {
        super.onPause()
        breathingAnimator?.cancel()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun observeData() {
        val dao = AppDatabase.getInstance(this).mediaDao()
        
        var total = 0
        var uploaded = 0
        var failed = 0

        dao.getTotalCount().observe(this) { count: Int? ->
            total = count ?: 0
            binding.tvTotalCount.text = total.toString()
            updateProgressBar(total, uploaded, failed)
        }
        dao.getUploadedCount().observe(this) { count: Int? ->
            uploaded = count ?: 0
            binding.tvUploadedCount.text = uploaded.toString()
            updateProgressBar(total, uploaded, failed)
        }
        dao.getPendingCount().observe(this) { count: Int? ->
            binding.tvPendingCount.text = (count ?: 0).toString()
        }
        dao.getFailedCount().observe(this) { count: Int? ->
            failed = count ?: 0
            binding.tvFailedCount.text = failed.toString()
            updateProgressBar(total, uploaded, failed)
        }
        
        dao.getFailedItems().observe(this) { items: List<MediaItem>? ->
            if (items != null) {
                currentFailedList = items
                updateFailedAdapterList()
                binding.cardFailedUploads.visibility = if (items.isEmpty()) View.GONE else View.VISIBLE
                updateFailedMoreButton(items.size)
            } else {
                binding.cardFailedUploads.visibility = View.GONE
            }
        }
    }

    private fun updateFailedAdapterList() {
        val listToDisplay = if (isFailedExpanded) {
            currentFailedList
        } else {
            currentFailedList.take(3)
        }
        failedAdapter?.submitList(listToDisplay)
    }

    private fun updateFailedMoreButton(totalCount: Int) {
        if (totalCount <= 3) {
            binding.btnFailedMore.visibility = View.GONE
        } else {
            binding.btnFailedMore.visibility = View.VISIBLE
            if (isFailedExpanded) {
                binding.btnFailedMore.text = getString(R.string.failed_less)
            } else {
                val moreCount = totalCount - 3
                binding.btnFailedMore.text = getString(R.string.failed_more, moreCount)
            }
        }
    }

    private fun updateProgressBar(total: Int, uploaded: Int, failed: Int) {
        val syncedTs = this.lastSyncedTs
        if (syncedTs > 0L) {
            val dateStr = SimpleDateFormat("dd/MM/yyyy HH:mm", Locale.getDefault()).format(Date(syncedTs))
            binding.tvLastSynced.text = getString(R.string.label_last_synced, dateStr)
        } else {
            binding.tvLastSynced.text = getString(R.string.never_synced)
        }

        if (this.resetFlag) {
            binding.tvProgressSubtext.text = "Full reset upload in progress: $uploaded of $total synced"
        } else {
            binding.tvProgressSubtext.text = getString(R.string.progress_idle).replace("Everything is up to date", "$uploaded of $total synced")
        }
        
        if (total > 0) {
            val percent = (uploaded.toFloat() / total.toFloat() * 100).toInt()
            binding.tvProgressPercent.text = "$percent%"
            
            val currentProgress = binding.progressBar.progress
            ValueAnimator.ofInt(currentProgress, uploaded).apply {
                duration = 800
                interpolator = DecelerateInterpolator()
                addUpdateListener { 
                    binding.progressBar.progress = it.animatedValue as Int
                    binding.progressBar.max = total
                }
                start()
            }
        } else {
            binding.tvProgressPercent.text = "0%"
            binding.progressBar.progress = 0
            binding.tvProgressSubtext.text = getString(R.string.progress_idle)
        }
        
        binding.btnRetryFailed.visibility = if (failed > 0) View.VISIBLE else View.GONE
    }

    private fun onRetryFailedClicked() {
        val intent = Intent(this, PhotoMonitorService::class.java).apply {
            action = PhotoMonitorService.ACTION_RETRY
        }
        startService(intent)
        showToast("Retrying failed uploads...")
    }

    private fun onUploadManuallyClicked() {
        if (isManualSharingInProgress) return
        
        lifecycleScope.launch(Dispatchers.IO) {
            val failedItems = AppDatabase.getInstance(this@MainActivity)
                .mediaDao()
                .getFailedItemsList()
            
            if (failedItems.isEmpty()) {
                withContext(Dispatchers.Main) {
                    showToast("No failed files to upload.")
                }
                return@launch
            }

            withContext(Dispatchers.Main) {
                isManualSharingInProgress = true
                binding.btnUploadManually.isEnabled = false
                showToast(getString(R.string.manual_share_preparing, failedItems.size))
            }

            // Limit to 50 files for system stability
            val itemsToShare = failedItems.take(50)
            val uris = ArrayList<Uri>()
            val pathsToRemove = ArrayList<String>()

            for (item in itemsToShare) {
                val file = java.io.File(item.filePath)
                if (file.exists()) {
                    try {
                        val uri = androidx.core.content.FileProvider.getUriForFile(
                            this@MainActivity,
                            "${packageName}.provider",
                            file
                        )
                        uris.add(uri)
                        pathsToRemove.add(item.filePath)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to get URI for ${item.filePath}", e)
                    }
                }
            }

            withContext(Dispatchers.Main) {
                if (uris.isEmpty()) {
                    showToast("None of the failed files exist on this device anymore.")
                    isManualSharingInProgress = false
                    binding.btnUploadManually.isEnabled = true
                    return@withContext
                }

                if (failedItems.size > 50) {
                    showToast(getString(R.string.manual_share_limit))
                }
                
                val shareIntent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
                    type = "*/*"
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                
                try {
                    startActivity(Intent.createChooser(
                        shareIntent,
                        "Upload ${uris.size} failed file(s) via..."
                    ))

                    // Once shared, mark them as DONE in DB so they are removed from failed list
                    withContext(Dispatchers.IO) {
                        AppDatabase.getInstance(this@MainActivity).mediaDao().markAsManuallyDone(pathsToRemove)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to launch share sheet", e)
                    showToast("Failed to open share sheet.")
                } finally {
                    isManualSharingInProgress = false
                    binding.btnUploadManually.isEnabled = true
                }
            }
        }
    }

    private fun onPauseUploadClicked() {
        if (!this.uploadPaused) {
            this.uploadPaused = true
            val intent = Intent(this, PhotoMonitorService::class.java).apply {
                action = "ACTION_PAUSE_UPLOAD"
            }
            startService(intent)
            showToast("Uploads paused. Monitoring continues.")
        } else {
            this.uploadPaused = false
            val intent = Intent(this, PhotoMonitorService::class.java).apply {
                action = "ACTION_RESUME_UPLOAD"
            }
            startService(intent)
            showToast("Uploads resumed.")
        }
        updateUi()
    }

    private fun onToggleClicked() {
        saveFields()

        if (this.botToken.isBlank() || this.channelId.isBlank()) {
            showToast("Please enter your Bot Token and Channel ID first.")
            return
        }

        if (this.monitoringEnabled) {
            stopMonitoringService()
        } else {
            this.configLocked = true
            requestPermissionsAndStart()
        }
    }

    private fun onValidateClicked() {
        saveFields()
        val token = this.botToken
        val channel = this.channelId

        if (token.isBlank()) {
            showToast("Enter your Bot Token first.")
            return
        }

        binding.tvBotName.text = "Checking connection…"
        binding.btnValidate.isEnabled = false

        lifecycleScope.launch {
            val fetchedBotName: String? = TelegramApi.getBotInfo(token)
            val fetchedChannelName: String? = if (channel.isNotBlank()) TelegramApi.getChannelInfo(token, channel) else null

            binding.btnValidate.isEnabled = true

            if (fetchedBotName != null) {
                this@MainActivity.botName = fetchedBotName
                binding.tvBotName.text = fetchedBotName
                
                if (channel.isNotBlank()) {
                    if (fetchedChannelName != null) {
                        this@MainActivity.channelName = fetchedChannelName
                        binding.tvChannelName.text = fetchedChannelName
                        showToast("Connection successful!")
                    } else {
                        binding.tvChannelName.text = "Channel not found or Bot is not admin"
                    }
                }
            } else {
                binding.tvBotName.text = "Invalid token"
                showToast("Token validation failed.")
            }
        }
    }

    private fun onLockClicked() {
        if (this.configLocked) {
            binding.btnLock.animate().rotation(20f).setDuration(150).withEndAction {
                binding.btnLock.animate().rotation(0f).setDuration(150).start()
                this.configLocked = false
                updateUi()
            }.start()
        } else {
            saveFields()
            if (this.botToken.isBlank() || this.channelId.isBlank()) {
                showToast("Please enter both Bot Token and Channel ID before locking.")
                return
            }
            this.configLocked = true
            updateUi()
            if (this.botName.isBlank() || this.channelName.isBlank()) {
                onValidateClicked()
            }
        }
    }

    private fun onResetClicked() {
        // First Confirmation Dialog
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("Reset ValtSky?")
            .setMessage("This will erase all sync history and progress. The app will re-upload your entire gallery from the beginning next time you start monitoring. This cannot be undone.")
            .setPositiveButton("Continue") { _, _ ->
                showSecondConfirmation()
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun showSecondConfirmation() {
        // Second Confirmation Dialog
        androidx.appcompat.app.AlertDialog.Builder(this)
            .setTitle("Are you absolutely sure?")
            .setMessage("All sync data will be permanently deleted. Your Telegram channel will not be affected — only the app's local data is cleared.")
            .setPositiveButton("Yes, Reset Everything") { _, _ ->
                performDeepReset()
            }
            .setNegativeButton("Go Back", null)
            .show()
    }

    private fun performDeepReset() {
        lifecycleScope.launch(Dispatchers.Main) {
            binding.btnReset.isEnabled = false
            binding.tvProgressSubtext.text = "Resetting... please wait"
            
            try {
                this@MainActivity.resetInProgress = true
                
                // Requirement Phase 3: Stop active service (must be on Main for updateUi)
                Log.i(TAG, "Phase 3: Stop active service")
                stopMonitoringService()
                
                withContext(Dispatchers.IO) {
                    Log.i(TAG, "Phase 1: Clear persistent state")
                    Prefs.clearAllSyncState(this@MainActivity)
                    this@MainActivity.uploadPaused = false

                    Log.i(TAG, "Phase 2: Clear Database")
                    AppDatabase.getInstance(this@MainActivity).mediaDao().deleteAll()

                    // Wait a moment for service to release resources
                    kotlinx.coroutines.delay(800)

                    Log.i(TAG, "Phase 5: Set Fresh Start Flag")
                    this@MainActivity.freshStartFlag = true
                }
                
                this@MainActivity.resetInProgress = false
            } catch (e: Exception) {
                Log.e(TAG, "Deep reset failed", e)
                this@MainActivity.resetInProgress = false
            }

            Log.i(TAG, "Phase 4: Reset UI")
            updateUi()
            showToast("Reset complete. Tap Start Monitoring to begin.")
            binding.btnReset.isEnabled = true
        }
    }

    private fun getOldestMediaDate(): Long {
        val projection = arrayOf(MediaStore.MediaColumns.DATE_ADDED)
        val uris = arrayOf(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        )
        var oldest = System.currentTimeMillis()
        try {
            for (uri in uris) {
                contentResolver.query(uri, projection, null, null, "${MediaStore.MediaColumns.DATE_ADDED} ASC LIMIT 1")?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val date = cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)) * 1000
                        if (date < oldest) oldest = date
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch oldest media date", e)
        }
        return oldest
    }

    private fun requestPermissionsAndStart() {
        val required = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                add(Manifest.permission.READ_MEDIA_IMAGES)
                add(Manifest.permission.READ_MEDIA_VIDEO)
                add(Manifest.permission.POST_NOTIFICATIONS)
            } else {
                add(Manifest.permission.READ_EXTERNAL_STORAGE)
            }
        }

        val missing = required.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (missing.isEmpty()) {
            startMonitoringService()
        } else {
            permissionLauncher.launch(missing.toTypedArray())
        }
    }

    private fun startMonitoringService() {
        val syncedTs = this.lastSyncedTs
        if (syncedTs > 0L) {
            val dateStr = SimpleDateFormat("dd/MM HH:mm", Locale.getDefault()).format(Date(syncedTs))
            showToast(getString(R.string.resuming_from, dateStr))
        }

        this.monitoringEnabled = true
        val intent = Intent(this, PhotoMonitorService::class.java)
            .apply { action = PhotoMonitorService.ACTION_START }
        ContextCompat.startForegroundService(this, intent)
        updateUi()
        Log.i(TAG, "Service started by user")
    }

    private fun stopMonitoringService() {
        this.monitoringEnabled = false
        this.uploadPaused = false
        val intent = Intent(this, PhotoMonitorService::class.java)
            .apply { action = PhotoMonitorService.ACTION_STOP }
        startService(intent)
        updateUi()
        Log.i(TAG, "Service stopped by user")
    }

    private fun checkBatteryOptimisation() {
        val pm = getSystemService(PowerManager::class.java)
        val ignored = pm?.isIgnoringBatteryOptimizations(packageName) == true
        binding.cardBatteryWarning.visibility = if (ignored) View.GONE else View.VISIBLE
    }

    private fun openBatterySettings() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                .apply { data = Uri.parse("package:$packageName") }
            startActivity(intent)
        } catch (e: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
            } catch (ex: Exception) {
                showToast("Please manually disable battery optimisation for this app.")
            }
        }
    }

    private fun updateUi() {
        val running = this.monitoringEnabled
        val locked = this.configLocked

        val themeIcon = when (this.selectedTheme) {
            Prefs.ThemeChoice.LIGHT -> R.drawable.ic_sun
            Prefs.ThemeChoice.DARK -> R.drawable.ic_moon
        }
        binding.btnThemeToggle.setImageResource(themeIcon)

        binding.btnToggle.text = if (running) getString(R.string.btn_stop) else getString(R.string.btn_start)
        binding.btnRefresh.alpha = if (running) 1.0f else 0.5f
        
        if (running) {
            binding.btnPauseUpload.visibility = View.VISIBLE
            binding.btnPauseUpload.text = if (this.uploadPaused) getString(R.string.btn_resume_upload) else getString(R.string.btn_pause_upload)
        } else {
            binding.btnPauseUpload.visibility = View.GONE
        }

        val statusColorAttr = if (running) R.attr.valtskyPrimaryAccent else R.attr.valtskySuccess
        val statusColor = getColorFromAttr(statusColorAttr)
        binding.tvSyncStatus.setTextColor(statusColor)
        binding.dotSyncing.backgroundTintList = ColorStateList.valueOf(statusColor)

        if (locked) {
            binding.btnLock.text = getString(R.string.btn_unlock)
            binding.settingsLockOverlay.visibility = View.VISIBLE
            binding.settingsLockOverlay.animate().alpha(1f).setDuration(200).start()
            binding.rowBot.animate().alpha(0.6f).setDuration(300).start()
            binding.rowChannel.animate().alpha(0.6f).setDuration(300).start()
            binding.rowNetwork.animate().alpha(0.6f).setDuration(300).start()
            binding.rowQuality.animate().alpha(0.6f).setDuration(300).start()
        } else {
            binding.btnLock.text = getString(R.string.btn_lock)
            binding.settingsLockOverlay.animate().alpha(0f).setDuration(200).withEndAction {
                binding.settingsLockOverlay.visibility = View.GONE
            }.start()
            binding.rowBot.animate().alpha(1f).setDuration(300).start()
            binding.rowChannel.animate().alpha(1f).setDuration(300).start()
            binding.rowNetwork.animate().alpha(1f).setDuration(300).start()
            binding.rowQuality.animate().alpha(1f).setDuration(300).start()
        }

        val canEdit = !running && !locked
        binding.etBotToken.isEnabled   = canEdit
        binding.etChannelId.isEnabled  = canEdit
        binding.swOriginalQuality.isEnabled = canEdit
        binding.btnValidate.isEnabled  = canEdit
        binding.rgNetwork.isEnabled    = canEdit

        binding.tvBotName.text = if (this.botName.isNotBlank()) this.botName else getString(R.string.not_connected)
        binding.tvChannelName.text = if (this.channelName.isNotBlank()) this.channelName else getString(R.string.not_connected)
    }

    private fun getColorFromAttr(attr: Int): Int {
        val typedValue = android.util.TypedValue()
        theme.resolveAttribute(attr, typedValue, true)
        return typedValue.data
    }

    private fun saveFields() {
        this.botToken    = binding.etBotToken.text.toString()
        this.channelId   = binding.etChannelId.text.toString()
        this.useOriginalQuality = binding.swOriginalQuality.isChecked
    }

    private fun restoreFields() {
        binding.etBotToken.setText(this.botToken)
        binding.etChannelId.setText(this.channelId)
        binding.swOriginalQuality.isChecked = this.useOriginalQuality
        
        val rbId = when (this.uploadNetworkType) {
            Prefs.NetworkTypeChoice.WIFI -> R.id.rbWifi
            Prefs.NetworkTypeChoice.MOBILE -> R.id.rbMobile
            Prefs.NetworkTypeChoice.BOTH -> R.id.rbBoth
        }
        binding.rgNetwork.check(rbId)
    }

    private fun showToast(msg: String) =
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()

    private fun startBreathingAnimation() {
        breathingAnimator?.cancel()
        breathingAnimator = ObjectAnimator.ofFloat(binding.dotSyncing, "alpha", 1f, 0.25f, 1f).apply {
            duration = 1800
            repeatCount = ValueAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator()
            start()
        }
    }

    private fun animateButtonPress(view: View) {
        view.animate()
            .scaleX(0.97f)
            .scaleY(0.97f)
            .setDuration(100)
            .withEndAction {
                view.animate()
                    .scaleX(1f)
                    .scaleY(1f)
                    .setDuration(100)
                    .start()
            }
            .start()
    }
}
