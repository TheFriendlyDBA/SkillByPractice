In your test or lab SQL Server environment, run the scripts in the following order:



01\_fn\_GetSessionsActivity.sql  

Creates a function that returns detailed information about all active user sessions on the SQL Server instance.



02\_sp\_Sessions.sql  

Creates a stored procedure that uses the above function to provide refined details about active sessions, including blocking information.



03\_fn\_GetLockInfo.sql  

Creates a function that helps you quickly identify which locks are held by a specific session, including detailed information about the affected databases and tables.

