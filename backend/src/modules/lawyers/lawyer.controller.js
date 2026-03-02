import Lawyer from "./lawyer.model.js";

// Register as lawyer
export const registerLawyer = async (req, res) => {
  try {
    const userId = req.user._id;

    const exists = await Lawyer.findOne({ user: userId });
    if (exists) return res.status(400).json({ error: "Already registered as lawyer" });

    const lawyer = await Lawyer.create({
      user: userId,
      name: req.body.name,
      email: req.body.email,
      phone: req.body.phone,
      specialization: req.body.specialization,
      city: req.body.city,
      experience_years: req.body.experience_years,
      bio: req.body.bio
    });

    res.json({ success: true, lawyer });
  } catch (err) {
    res.status(500).json({ error: "Failed to register lawyer" });
  }
};

// Get all lawyers (public)
export const getLawyers = async (req, res) => {
  try {
    const lawyers = await Lawyer.find().select("-phone -email"); // hide contact initially
    res.json(lawyers);
  } catch {
    res.status(500).json({ error: "Failed to fetch lawyers" });
  }
};

import Connection from "./connection.model.js";

// User sends request
export const sendRequest = async (req, res) => {
  try {
    const userId = req.user._id;
    const { lawyerId, query } = req.body;

    const request = await Connection.create({
      user: userId,
      lawyer: lawyerId,
      query
    });

    res.json({ success: true, request });
  } catch {
    res.status(500).json({ error: "Failed to send request" });
  }
};

// Lawyer sees incoming requests
export const getLawyerRequests = async (req, res) => {
  try {
    const lawyer = await Lawyer.findOne({ user: req.user._id });
    if (!lawyer) return res.status(403).json({ error: "Not a lawyer" });

    const requests = await Connection.find({ lawyer: lawyer._id })
      .populate("user", "email");

    res.json(requests);
  } catch {
    res.status(500).json({ error: "Failed to fetch requests" });
  }
};

export const respondToRequest = async (req, res) => {
  try {
    const { requestId, status } = req.body;

    const request = await Connection.findByIdAndUpdate(
      requestId,
      { status },
      { new: true }
    );

    res.json(request);
  } catch {
    res.status(500).json({ error: "Failed to update request" });
  }
};

export const getUserConnections = async (req, res) => {
  try {
    const requests = await Connection.find({ user: req.user._id })
      .populate({
        path: "lawyer",
        select: "name email phone specialization city"
      });

    // hide contact if not accepted
    const result = requests.map(r => {
      if (r.status !== "accepted") {
        r.lawyer.email = undefined;
        r.lawyer.phone = undefined;
      }
      return r;
    });

    res.json(result);
  } catch {
    res.status(500).json({ error: "Failed" });
  }
};