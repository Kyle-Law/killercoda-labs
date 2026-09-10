
<br>

Every other networking lab in this repo starts from a cluster that already has a working pod network. This one takes it away.

The CNI is the only part of Kubernetes that ships as a blank. `kubeadm init` finishes, prints a join command, and hands you a cluster where nothing can run — the node reports `NotReady` and stays there until you install something the project deliberately does not include. That gap is where a lot of exam questions live, because the failure is loud but the message points at the kubelet rather than at the thing that's missing.

The cluster you're about to get has had its CNI removed. `kubectl` still works — you'll find out why in the first step — but nothing else does.

By the end you'll have installed one properly, and you'll be able to say exactly what "installing a CNI" writes to a node: it is smaller than most people expect, and the part that matters isn't the part in the config file.

Every step here builds a task, not a solution — work it out yourself first, use the **Tip** if you're stuck, and check the **Solution** only once you've tried.
