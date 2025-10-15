---
mode: agent
tools: [codebase]
description: Optimize performance of Mixpanel operations
---
# Performance Optimization Task

Optimize performance for: ${input:component:Component or operation to optimize}

## Performance Analysis Steps

1. **Identify bottlenecks**:
   - Profile with Instruments
   - Check queue congestion
   - Monitor memory usage
   - Measure operation timing

2. **Common optimization areas**:
   - **Batch operations**: Process multiple items together
   - **Queue management**: Optimize dispatch patterns
   - **Memory usage**: Reduce allocations and copies
   - **SQLite queries**: Add indexes, optimize queries
   - **Network calls**: Batch requests, compress data

3. **Optimization techniques**:
   ```swift
   // Batch processing
   let batchSize = 50
   for batch in entities.chunked(into: batchSize) {
       processBatch(batch)
   }
   
   // Efficient queue usage
   trackingQueue.async(flags: .barrier) {
       // Exclusive write operation
   }
   ```

4. **Memory optimization**:
   - Use autoreleasepool for loops
   - Weak references where appropriate
   - Clear caches when needed
   - Profile for leaks

5. **SQLite optimization**:
   - Create appropriate indexes
   - Use transactions for bulk operations
   - Optimize query patterns
   - Regular VACUUM operations

6. **Testing performance**:
   - Measure before and after
   - Test with large datasets (10k+ events)
   - Test on older devices
   - Monitor battery impact

## Performance patterns to follow:
- Reference Flush.swift for batch processing
- See MixpanelPersistence for SQLite optimization
- Check AutomaticEvents for efficient property collection