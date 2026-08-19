
<br>

A Pod stuck `Pending` with a `Ready` node behind it always means a scheduling constraint the Pod doesn't satisfy. Three different constraints, three different fixes — `kubectl describe pod` and its `Events` section is the diagnostic for all three.

> This cluster has exactly one node, which makes the third step's lesson sharper, not weaker: some constraints (like "don't put two of these on the same node") are only satisfiable with more nodes than you have. Recognizing that is as much the skill as writing the constraint in the first place.
