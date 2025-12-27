In your test/Lab server, you can run the following

1) 01_TempDBStress.ps1 to reproduce Tempdb contention problem
2) 02_monitorSessions.sql file to monitor each session and to identify issue
3) 03_TempDBStress.sql - this file is extra, just incase you want to work directly with T-SQL and not PowerShell to reproduce Tempdb contention issue.
