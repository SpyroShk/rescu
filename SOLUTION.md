# Rescu — Flutter Developer Assessment

Here are the solutions for each of the problems in the Rescu.

### RES-101 · Search shows results for the wrong query

Type a word quickly in search — for example "sushi", letter by letter.
Frequently the final results do not match what is in the text box: correct
results appear briefly, then get replaced by results for an earlier, shorter
query. Team reproduces this most attempts. Users report "search is drunk".

### RES-101 Solution

**Root cause:**

Continuous spamming of API calls on each letter/ multiple request at once.

**Fix:**

1. Using Debounce to reduce how many requests get fired in the first place (efficiency/UX). Without it, typing "sushi" fires 5 separate API calls (s, su, sus, sush, sushi) as the user types each letter. That's wasteful, hammering your backend for results the user will never even see, since they kept typing past each one.
2. Using SearchId guard to ensure correctness when multiple requests are still in flight at once (correctness/data integrity). And only show the latest search results by comparing the searchId's and discarding the previous result.

I thought to just use the SearchId guard and leave it as is and it would solve the problem but, I didn't leave it at that as the continuous API spamming would cause more performance issue.

The fix didnt take that long as the bug was obvious and was solved under 30 min. Also no AI used for this one.

### RES-102 · Crash after leaving My orders

Open **My orders** while there is an order with an upcoming pickup, then
navigate back. Within a couple of seconds the app crashes in debug builds with
`setState() called after dispose()`.

### RES-102 Solution

**Root cause:**

Timer.periodic in PickupCountdown is created without canceling it, so it continues firing after PickupCountdown is removed when popping out of OrdersScreen and calls setState on a disposed state.

**Fix:**

1. The periodic timer is now stored, canceled in dispose(), and guarded with mounted. If the timer wasn't cancelled it would continue existing even after popping out of the page and give error.

The fix took few min to find that PickupCountdown was using periodic Timer and it wasnt disposed causing the bug and was solved under few minutes. For the use of AI, Copilot suggested to check if it was mounted or not using if statement while initializing.

### RES-103 · Requests pile up the longer you browse

After opening several deal pages, every tap on "Add to bag" triggers a burst
of `GET /deals/:id` requests — one for _each deal viewed earlier in the
session_, even for screens that were closed long ago. The app gets slower
and chattier the longer the session. Watch the console logs while browsing
to see it (every simulated request is logged).

### RES-103 Solution

**Root cause:**

The cause is in onInit of DealDetailsController where each page registers an ever(...) worker on the app-wide cart observable, but the returned Worker is discarded, so closing the page never unregisters that listener.

**Fix:**

1. I disposed the worker in onClose in DealDetailsController. This removes old controllers while preserving the stock refresh for the active page. Each controller now stores its cart listener and disposes it in onClose(), preventing closed deal pages from reacting to future “Add to bag” events.

The fix took me around 30 to 40 minutes as I have never worked with workers before and took me some time to learn what ever, everAll, once and debounce did. The used worker, ever() wasnt disposed causing the bug and was solved under few minutes after found. Researched about the workers rather the use AI to solve this issue.
