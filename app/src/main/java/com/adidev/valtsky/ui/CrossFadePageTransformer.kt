package com.adidev.valtsky.ui

import android.view.View
import androidx.viewpager2.widget.ViewPager2
import kotlin.math.abs

class CrossFadePageTransformer : ViewPager2.PageTransformer {
    override fun transformPage(page: View, position: Float) {
        page.translationX = -position * page.width

        page.alpha = when {
            position < -1 -> 0f
            position <= 1 -> 1 - abs(position)
            else -> 0f
        }
    }
}
