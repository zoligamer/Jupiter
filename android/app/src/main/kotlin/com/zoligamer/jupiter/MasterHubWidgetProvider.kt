package com.zoligamer.jupiter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class MasterHubWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_master_hub).apply {
                // 1. Következő óra adatok (Terem, idősáv, állapot-badge)
                val room = widgetData.getString("class_room", "📍 --:--") ?: "📍 --:-- "
                val time = widgetData.getString("class_time", "--:-- - --:--") ?: "--:-- - --:--"
                val badge = widgetData.getString("class_time_remaining", "Órarend") ?: "Órarend"

                setTextViewText(R.id.hub_class_room, room)
                setTextViewText(R.id.hub_class_time, "⏱️ $time")
                setTextViewText(R.id.hub_class_badge, badge)

                // 2. Üzenetek állapot (Ikon + pötty/szám vagy pipa)
                val unreadCount = widgetData.getInt("messages_count", 0)
                val messagesDisplay = if (unreadCount > 0) "✉️ ● $unreadCount" else "✉️ ✓"
                setTextViewText(R.id.hub_messages_text, messagesDisplay)

                // 3. Kredit progress állapot (Ikon + kredit érték)
                val earnedCredits = widgetData.getInt("credits_earned", 0)
                val creditsDisplay = if (earnedCredits > 0) "🎓 $earnedCredits kr" else "🎓 -- kr"
                setTextViewText(R.id.hub_credits_text, creditsDisplay)

                // 4. Teendők állapot (Ikon + pötty/szám vagy pipa)
                val taskCount = widgetData.getInt("tasks_count", 0)
                val tasksDisplay = if (taskCount > 0) "📋 ● $taskCount" else "📋 ✓"
                setTextViewText(R.id.hub_tasks_text, tasksDisplay)

                // Kattintáskezelők (Deep linking célzott fülekhez)
                setOnClickPendingIntent(
                    R.id.hub_class_section,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("jupiter://open?tab=timetable"))
                )
                setOnClickPendingIntent(
                    R.id.hub_messages_box,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("jupiter://open?tab=messages"))
                )
                setOnClickPendingIntent(
                    R.id.hub_credits_box,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("jupiter://open?tab=markbook"))
                )
                setOnClickPendingIntent(
                    R.id.hub_tasks_box,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("jupiter://open?tab=questionnaires"))
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("jupiter://open?tab=timetable"))
                )
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
