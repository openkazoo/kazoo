# 0001: Separation protects ecallmgr's state, not call audio

## Starting model

Noah reasoned that a separate ecallmgr node adds nothing, for two reasons: ecallmgr can't do anything useful without kapps like callflow, and restarting ecallmgr doesn't end in-progress calls.

## Insight taught

- Both premises are right. Bridged audio lives in FreeSWITCH, ecallmgr re-syncs channels on boot, and new calls need callflow whatever the layout.
- ruhnet's argument runs the other way: it's about kapp-side restarts and faults leaving ecallmgr up. While the kapps are gone, ecallmgr still answers SIP auth from its local cache, keeps the FreeSWITCH link and channel tracking, runs the balance crawler, and falls back on authz.
- The argument is weaker than stated in two places. A plain kapp crash is already contained in a combined node, because kapps are `temporary` apps. Config reloads can use `kapps_controller:restart_app/1`. Its strong form is VM-wide faults (OOM, system limits) and full-node restarts.
- PR #76 only changes the fallback default, and separate layouts remain configurable.

## Next

- Confirm the mission.
- Possible lesson 2: measure it. Boot a combined node and a split layout, restart the kapps, and watch REGISTERs and the auth-cache hits in the logs.
