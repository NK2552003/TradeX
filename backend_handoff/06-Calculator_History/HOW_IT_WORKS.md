# 06 Calculator History

## Overview

This feature needs backend linking and RLS setup. Check the schema and RLS policies for exact details.

Calculator History stores previously calculated scenarios (e.g. position sizing, risk/reward) for future reference.


## Cron Jobs
- A daily cron job to delete calculator history entries older than 30 days, or limit to the last 100 entries per user.
