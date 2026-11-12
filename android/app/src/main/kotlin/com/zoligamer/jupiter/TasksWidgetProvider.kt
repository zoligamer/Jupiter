package com.zoligamer.jupiter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TasksWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_tasks).apply {
                val count = widgetData.getInt("tasks_count", 0)
                val countBadge = widgetData.getString("tasks_count_badge", if (count > 0) "$count teendő" else "0 teendő")
                val title = widgetData.getString("tasks_title", "Minden teendő elvégezve! ✅")
                val deadline = widgetData.getString("tasks_deadline", "Kérdőívek és feladatok")

                setTextViewText(R.id.widget_tasks_count_badge, countBadge)
                setTextViewText(R.id.widget_tasks_title, title)
                setTextViewText(R.id.widget_tasks_deadline, deadline)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jupiter://open?tab=tasks")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
