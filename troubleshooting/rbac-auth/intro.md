
<br>

"Forbidden" errors are one bug with three different real causes: no binding at all, a binding to a Role that doesn't grant enough, or a binding that can't reach the resource it's targeting because of scope. `kubectl auth can-i ... --as=<identity>` is the diagnostic for all three — learn to reach for it before guessing.
