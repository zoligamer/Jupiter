package com.zoligamer.jupiter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PeriodsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_periods).apply {
                val title = widgetData.getString("period_title", "Nincs aktív időszak")
                val remaining = widgetData.getString("period_remaining", "Időszakok megtekintése")
                val badge = widgetData.getString("period_badge", "Infó")

                setTextViewText(R.id.widget_period_title, title)
                setTextViewText(R.id.widget_period_remaining, remaining)
                setTextViewText(R.id.widget_period_badge, badge)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jupiter://open?tab=periods")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
