
<br>

Every `helm upgrade` creates a new **revision**, and Helm keeps the old ones. That's what makes a rollback possible — and it means a bad release is recoverable without knowing what the previous configuration was.

A release called `webserver` has been through three revisions. The most recent one is broken.
