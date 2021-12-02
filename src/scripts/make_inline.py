import os

scripts_dir = os.path.dirname(os.path.abspath(__file__))

notify_py = None
with open(os.path.join(scripts_dir, "notify.py"), "r") as f:
    notify_py = f.read()

notify_py = notify_py.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$")

notify_inline = f'python -c "{notify_py}"'
with open(os.path.join(scripts_dir, "notify_inline.sh"), "w") as f:
    f.write(notify_inline)
