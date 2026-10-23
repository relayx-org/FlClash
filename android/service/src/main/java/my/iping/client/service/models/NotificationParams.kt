package my.iping.client.service.models

data class NotificationParams(
    val title: String = "iPing",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
    val showStopAction: Boolean = true,
)
