using Xunit;

// These are integration tests hitting a real MySQL server. Even with a
// unique database name per test class, concurrent DDL (EnsureCreated/
// EnsureDeleted) across classes contends on MySQL's internal metadata
// locks and produces spurious failures — so run test classes sequentially.
[assembly: CollectionBehavior(DisableTestParallelization = true)]
