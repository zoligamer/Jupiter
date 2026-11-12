package com.zoligamer.jupiter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MessagesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_messages).apply {
                val count = widgetData.getInt("messages_count", 0)
                val countBadge = widgetData.getString("messages_count_badge", if (count > 0) "$count új ✉️" else "0 új ✅")
                val preview = widgetData.getString("messages_preview", "Nincs új olvasatlan üzenet! ✅")
                val sender = widgetData.getString("messages_sender", "Üzenetközpont")

                setTextViewText(R.id.widget_messages_count_badge, countBadge)
                setTextViewText(R.id.widget_messages_content, preview)
                setTextViewText(R.id.widget_messages_sender, sender)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("jupiter://open?tab=messages")
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
