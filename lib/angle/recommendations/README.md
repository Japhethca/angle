# Angle Recommendations

Hybrid recommendation engine providing personalized item recommendations.

## Architecture

- **Data Model:** UserInterest, ItemSimilarity, RecommendedItem resources
- **Scoring:** Interest-based, similarity-based, and collaborative filtering
- **Jobs:** Oban background jobs for pre-computation
- **Caching:** ETS for hot paths, PostgreSQL for persistence
- **Serving:** Domain functions with graceful fallbacks

## Recommendation Contexts

### Homepage - "Recommended for You"
- Pre-computed, refreshed every 1-2 hours
- Falls back to popular items for new users
- API: `Recommendations.get_homepage_recommendations(user_id, limit: 20)`

### Item Detail - "Similar Items"
- Pre-computed daily, served from ETS cache
- Falls back to same-category items
- API: `Recommendations.get_similar_items(item_id, limit: 8)`

### Post-Bid - "You Might Also Like"
- Real-time computation after bid
- Falls back to category popular items
- API: `Recommendations.generate_post_bid_recommendations/2` (to be implemented)

## Background Jobs

### RefreshUserInterests
- **Schedule:** Hourly
- **Queue:** `:recommendations`
- **Purpose:** Compute user interest profiles

Run manually: `Oban.insert(Angle.Recommendations.Jobs.RefreshUserInterests.new(%{}))`

## Cache Management

ETS tables:
- `:similar_items_cache` - Pre-computed similar items
- `:popular_items_cache` - Popular items fallback

Clear caches: `Angle.Recommendations.Cache.clear_all()`

## Testing

Run all recommendation tests:
```bash
mix test test/angle/recommendations/
```

## Performance Targets

| Context | Latency | Method |
|---------|---------|--------|
| Homepage | <50ms | Pre-computed |
| Item Detail | <10ms | ETS cache |
| Post-Bid | <200ms | Real-time |
