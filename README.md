# tide stamp

A small app that reminds you to do important repetitive things you forget to do.

![Alt Text](https://media1.giphy.com/media/v1.Y2lkPTc5MGI3NjExeGkzaDA4czlycmRnbTE4YXRtNzBuaWNzemhiM3hhZjR1czc3MDBxMyZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/2seIEHw69Mp2FGLNVM/giphy.gif)

## To run
```
swift run TideStamp
```

## Data Management 
1. Current reminder settings
- key: `reminderItems`
- stored: id, title, intervalMinutes
- To delete: `defaults delete TideStamp reminderItems`

2. Dashboard progress
- key: `achievementProgressByDay`
- stored: released, completed
- To delete: `defaults delete TideStamp achievementProgressByDay`

3. Tracked item history
- key: `trackedReminderItems`
- stored: id, title, intervalMinutes, firstActiveDay, deletedDay
- To delete: `defaults delete TideStamp trackedReminderItems`