package com.adidev.valtsky.ui

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.adidev.valtsky.R

class GuidePagerAdapter : RecyclerView.Adapter<GuidePagerAdapter.GuideViewHolder>() {

    private val layouts = listOf(
        R.layout.guide_page_setup,
        R.layout.guide_page_permissions,
        R.layout.guide_page_precautions
    )

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): GuideViewHolder {
        val view = LayoutInflater.from(parent.context).inflate(viewType, parent, false)
        return GuideViewHolder(view)
    }

    override fun onBindViewHolder(holder: GuideViewHolder, position: Int) {
        // No dynamic binding needed for static guide pages
    }

    override fun getItemCount(): Int = layouts.size

    override fun getItemViewType(position: Int): Int = layouts[position]

    class GuideViewHolder(view: View) : RecyclerView.ViewHolder(view)
}
