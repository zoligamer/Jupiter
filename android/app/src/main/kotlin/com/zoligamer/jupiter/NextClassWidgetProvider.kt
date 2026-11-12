package com.zoligamer.jupiter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NextClassWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_next_class).apply {
                val title = widgetData.getString("class_title", "Nincs több órád mára! 🎉")
                val room = widgetData.getString("class_room", "")
                val time = widgetData.getString("class_time", "--:-- - --:--")
                val countdown = widgetData.getString("class_countdown", "Órarend")

                setTextViewText(R.id.widget_class_title, title)
                setTextViewText(R.id.widget_class_room, if (!room.isNullOrEmpty()) room else "Terem")
                setTextViewText(R.id.widget_class_time, time)
                setTextViewText(R.id.widget_class_countdown, countdown)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jupiter://open?tab=timetable")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
