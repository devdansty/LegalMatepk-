/**
 * Monitoring endpoint for Google Cloud API usage
 * Provides real-time stats on translation usage and daily limits
 */

import { 
  getUsageStats, 
  getUsageWarning, 
  formatUsageStats,
  getCacheStats 
} from "../../shared/language/translation.service.js";

export const getTranslationStats = (req, res) => {
  try {
    const usageStats = getUsageStats();
    const warning = getUsageWarning();
    const cacheStats = getCacheStats();

    // Calculate if using fallback
    const isUsingFallback = usageStats.usagePercentage === '100.00%';

    res.json({
      success: true,
      data: {
        googleAPI: {
          ...usageStats,
          warning,
          usingFallback: isUsingFallback
        },
        cache: cacheStats,
        timestamp: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error("Stats Error:", error.message);
    res.status(500).json({
      success: false,
      error: "Could not retrieve statistics"
    });
  }
};

export const getFormattedStats = (req, res) => {
  try {
    const stats = formatUsageStats();

    res.json({
      success: true,
      stats: stats.split('\n').map(line => line.trim()).filter(line => line),
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error("Formatted Stats Error:", error.message);
    res.status(500).json({
      success: false,
      error: "Could not retrieve statistics"
    });
  }
};
