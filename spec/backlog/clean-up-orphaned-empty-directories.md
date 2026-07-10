## **Story: [tech] Clean up orphaned empty directories left by open_date's eager mkdir**

**Use Case:** `open_date` creates the year/month directory for a date before the buffer even exists, so an unedited buffer that's later discarded (e.g. an unwritten future preview) can leave an empty, orphaned directory behind on disk. Low-fidelity placeholder — not elaborated yet; revisit if this actually turns out to bother anyone in practice.
