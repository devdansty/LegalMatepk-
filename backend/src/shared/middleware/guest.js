import Session from "../../modules/sessions/session.model.js";

/**
 * Middleware to track and limit guest user API calls
 * Should be used after requireAuth or authIfPresent middleware
 * Checks guest call limit and increments counter
 */
export const trackGuestCall = (opts = {}) => {
  return async (req, res, next) => {
    if (!req.user || !req.user.is_guest) {
      // Not a guest user, proceed normally
      return next();
    }

    if (!req.session) {
      // No session found, block guest call
      return res.status(403).json({ error: "Invalid session for guest user" });
    }

    // Check if guest has reached call limit
    if (req.session.guest_api_calls >= req.session.guest_call_limit) {
      return res.status(403).json({ 
        error: "Guest session limit reached (5 API calls). Please sign up to continue.",
        call_limit: req.session.guest_call_limit,
        remaining_calls: 0
      });
    }

    // Increment call counter
    req.session.guest_api_calls += 1;
    await req.session.save();

    // Attach remaining calls info to response
    const remainingCalls = req.session.guest_call_limit - req.session.guest_api_calls;
    res.locals.guestCallInfo = {
      call_limit: req.session.guest_call_limit,
      remaining_calls: remainingCalls,
      is_guest_limit_warning: remainingCalls <= 1 // Warn when 1 call left
    };

    next();
  };
};

/**
 * Helper to add guest call info to JSON responses
 * Use after trackGuestCall middleware to include remaining calls in response
 */
export const includeGuestCallInfo = (responseData) => {
  return (req, res, next) => {
    if (res.locals.guestCallInfo) {
      responseData.guest_session = {
        remaining_calls: res.locals.guestCallInfo.remaining_calls,
        call_limit: res.locals.guestCallInfo.call_limit,
        warning: res.locals.guestCallInfo.is_guest_limit_warning ? 
          "You have limited API calls remaining. Please sign up for unlimited access." : 
          null
      };
    }
    next();
  };
};
