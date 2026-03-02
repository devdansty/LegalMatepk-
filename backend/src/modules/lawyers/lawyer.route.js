import {
  sendRequest,
  getLawyerRequests,
  respondToRequest,
  getUserConnections
} from "./lawyer.controller.js";

// user sends request
router.post("/request", requireAuth(), sendRequest);

// lawyer dashboard
router.get("/requests/incoming", requireAuth(), getLawyerRequests);

// lawyer accepts/rejects
router.post("/requests/respond", requireAuth(), respondToRequest);

// user sees accepted lawyers
router.get("/my-connections", requireAuth(), getUserConnections);