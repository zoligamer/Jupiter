package com.zoligamer.jupiter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CreditsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_credits).apply {
                val earned = widgetData.getInt("credits_earned", 0)
                val total = widgetData.getInt("credits_total", 0)
                val mainText = widgetData.getString("credits_main", if (total > 0) "$earned / $total kredit" else "$earned kredit")
                val percent = widgetData.getString("credits_percent", "$earned felvéve")
                val avg = widgetData.getString("credits_average", "Átlag: --")
                val scholarship = widgetData.getString("credits_scholarship", "Ösztöndíj: --")

                setTextViewText(R.id.widget_credits_main, mainText)
                setTextViewText(R.id.widget_credits_percent, percent)
                setTextViewText(R.id.widget_credits_average, avg)
                setTextViewText(R.id.widget_credits_scholarship, scholarship)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jupiter://open?tab=markbook")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
