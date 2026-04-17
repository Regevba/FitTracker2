"""U3 Cache Controller tests. Stateful: scratchpad SRAM with LRU eviction and compression. 15 entries, 48KB scratchpad, 16KB prefetch staging."""
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from units.types import CacheEntry

def test_put_and_get():
    from units.cache_controller import CacheController
    cc = CacheController(max_entries=15)
    entry = CacheEntry(key="dev_L1", compressed_view="dev skill summary", full_entry="full content")
    cc.put(entry)
    result = cc.get("dev_L1")
    assert result is not None
    assert result.compressed_view == "dev skill summary"

def test_get_miss_returns_none():
    from units.cache_controller import CacheController
    cc = CacheController(max_entries=15)
    assert cc.get("nonexistent") is None

def test_lru_eviction():
    from units.cache_controller import CacheController
    cc = CacheController(max_entries=3)
    cc.put(CacheEntry(key="a", compressed_view="a"))
    cc.put(CacheEntry(key="b", compressed_view="b"))
    cc.put(CacheEntry(key="c", compressed_view="c"))
    cc.get("a")  # make a recently used
    cc.put(CacheEntry(key="d", compressed_view="d"))  # should evict b
    assert cc.get("b") is None
    assert cc.get("a") is not None
    assert cc.get("d") is not None

def test_hit_miss_counters():
    from units.cache_controller import CacheController
    cc = CacheController(max_entries=15)
    cc.put(CacheEntry(key="x", compressed_view="x"))
    cc.get("x")       # hit
    cc.get("missing")  # miss
    cc.get("x")       # hit
    assert cc.stats["L1_hits"] == 2
    assert cc.stats["L1_misses"] == 1
    assert cc.hit_rate() == 2 / 3

def test_compressed_view_returned_by_default():
    from units.cache_controller import CacheController
    cc = CacheController(max_entries=15)
    cc.put(CacheEntry(key="k", compressed_view="short", full_entry="very long full content"))
    result = cc.get("k")
    assert result.compressed_view == "short"
    full = cc.expand("k")
    assert full == "very long full content"

def test_expand_miss_returns_none():
    from units.cache_controller import CacheController
    cc = CacheController(max_entries=15)
    assert cc.expand("nope") is None
