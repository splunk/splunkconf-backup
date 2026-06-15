---
layout: default
title: Resync-cloned-repository
---
---
layout: default
title: Resync-cloned-repository
---
to resync your cloned repository after main repository was updated

* go into your cloned repository, make sure you reload page if necessary
* if they are a changes, you will see a resync repository with added and removed stuff (especially if you changed topology from default)
* clic on "Sync Changes"
* Depending on the changes made upfront, that may do a full resync , this is expected but the Github action will automaticallly run after resync and move files again to match topology targeted (as your variable stay local)
If that double run happen, you will have a commit starting with TOPOLOGY change. if you run in VCS mode , make sure to discard the first run and only apply the second one that include TOPOLOGY (which the commit message will tell you to do)
