README
======

Time Based Furnaces
-------------------

Version: 206608
Author: fairiestoy

Description:
------------

This furnaces have the goal to work without ABMs or
NodeTimers and should be resistend against lags, since
they are calculating the results based on the time
passed by since last right-clicking it.

Version History:
----------------

> 70160
	Initial commit and first basic design
> 135696
	Rewritten the code a bit more, but still has this ugly bug
> 206608
	A way better rewrite. Put some routines in external
	functions and made the code more executable. Known
	Bugs: First fuel item is not consumed, so has a little
	exploit feeling