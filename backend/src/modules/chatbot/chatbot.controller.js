import { chatBotApi } from "./chatbot.service.js";
import ChatHistory from "./chathistory.model.js";

export const handleChat = async (req, res) => {
  try {
    const { message } = req.body;
    const startTime = Date.now();

    const reply = await chatBotApi(message);
    const processingTime = Date.now() - startTime;

    // Save chat history if user is authenticated
    let chatRecord = null;
    if (req.user) {
      chatRecord = await ChatHistory.create({
        user: req.user._id,
        message: {
          text: message,
          language: req.user.preferred_language || 'ur'
        },
        response: {
          text: reply,
          language: req.user.preferred_language || 'ur'
        },
        original_language: req.user.preferred_language || 'ur',
        session_id: req.session?._id || null,
        is_guest: req.user.is_guest || false,
        processing_time_ms: processingTime
      });
    }

    const response = {
      success: true,
      reply,
      processing_time_ms: processingTime
    };

    // Add guest call info if available
    if (res.locals.guestCallInfo) {
      response.guest_session = {
        remaining_calls: res.locals.guestCallInfo.remaining_calls,
        call_limit: res.locals.guestCallInfo.call_limit,
        warning: res.locals.guestCallInfo.is_guest_limit_warning ? 
          "You have limited API calls remaining. Please sign up for unlimited access." : 
          null
      };
    }

    res.json(response);

  } catch (error) {
    console.error("Chatbot Error:", error.message);
    console.error("Full Error:", error);

    res.status(500).json({
      success: false,
      error: "Chatbot unavailable",
      details: error.message
    });
  }
};

/**
 * Get chat history for authenticated user
 */
export const getChatHistory = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const limit = req.query.limit ? parseInt(req.query.limit) : 50;
    const skip = req.query.skip ? parseInt(req.query.skip) : 0;

    const history = await ChatHistory
      .find({ user: req.user._id, is_guest: false })
      .sort({ created_at: -1 })
      .limit(limit)
      .skip(skip)
      .select('message response original_language processing_time_ms created_at');

    const total = await ChatHistory.countDocuments({ user: req.user._id, is_guest: false });

    res.json({
      success: true,
      history,
      pagination: {
        total,
        limit,
        skip,
        remaining: Math.max(0, total - (skip + limit))
      }
    });
  } catch (error) {
    console.error("Get chat history error:", error);
    res.status(500).json({ error: "Failed to retrieve chat history" });
  }
};

/**
 * Clear chat history (optional, for user privacy)
 */
export const clearChatHistory = async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const result = await ChatHistory.deleteMany({ user: req.user._id });

    res.json({
      success: true,
      deleted_count: result.deletedCount,
      message: "Chat history cleared"
    });
  } catch (error) {
    console.error("Clear chat history error:", error);
    res.status(500).json({ error: "Failed to clear chat history" });
  }
};