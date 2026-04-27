import crypto from "crypto";
import jwt from "jsonwebtoken";
import argon2 from "argon2";
import validator from "validator";

import Lawyer from "./lawyer.model.js";
import User from "../users/user.model.js";
import Connection from "./connection.model.js";
import { setAndSendEmailOtp } from "../users/user.controller.js";

const ALLOWED_SPECIALIZATIONS = [
  "family",
  "criminal",
  "corporate",
  "property",
  "cybercrime",
  "immigration"
];

// ===== JWT & Session Helper =====
const signJwt = (userId) => {
  return jwt.sign({ sub: userId }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXP || '15m' });
};

// ===== CNIC Validation =====
const validateCNIC = (cnic) => {
  // Format: XXXXX-XXXXXXX-X (5 digits, hyphen, 7 digits, hyphen, 1 digit)
  const cnicRegex = /^\d{5}-\d{7}-\d{1}$/;
  return cnicRegex.test(cnic);
};

const normalizeSpecialization = (value) => {
  if (!value) return [];

  if (Array.isArray(value)) {
    return value
      .flatMap((item) => String(item).split(","))
      .map((item) => item.trim().toLowerCase())
      .filter(Boolean);
  }

  return String(value)
    .split(",")
    .map((item) => item.trim().toLowerCase())
    .filter(Boolean);
};

const sanitizeLawyerListItem = (lawyerDoc) => ({
  id: lawyerDoc._id,
  name: lawyerDoc.name,
  specialization: lawyerDoc.specialization,
  city: lawyerDoc.city,
  bio: lawyerDoc.bio,
  experience_years: lawyerDoc.experience_years,
  verified: lawyerDoc.verified,
  is_visible: lawyerDoc.is_visible
});

const getOrCreateGuestCitizenUser = async () => {
  const guestEmail = process.env.LAWYER_CONNECT_GUEST_EMAIL || "guest.lawyerconnect@legalmate.local";

  let guestUser = await User.findOne({ email: guestEmail.toLowerCase() });
  if (guestUser) {
    return guestUser;
  }

  const passwordHash = await argon2.hash(
    process.env.LAWYER_CONNECT_GUEST_PASSWORD || crypto.randomBytes(24).toString("hex"),
    { type: argon2.argon2id }
  );

  guestUser = await User.create({
    email: guestEmail.toLowerCase(),
    password_hash: passwordHash,
    phone: process.env.LAWYER_CONNECT_GUEST_PHONE || null,
    profile: {
      display_name: process.env.LAWYER_CONNECT_GUEST_NAME || "Guest Citizen"
    },
    role: "citizen",
    status: "active",
    consent: {
      tos_accepted: true,
      tos_accepted_at: new Date()
    }
  });

  return guestUser;
};

/**
 * Lawyer Sign Up - Creates both User and Lawyer accounts
 * This is a PUBLIC endpoint (no auth required)
 * POST /api/lawyers/signup
 */
export const lawyerSignup = async (req, res) => {
  try {
    const { 
      name, email, phone, password, 
      cnic, enrollment_number, bar_council,
      specialization, city, experience_years, bio 
    } = req.body;
    const normalizedSpecialization = normalizeSpecialization(specialization);

    // ===== VALIDATION =====
    
    // Check required fields
    if (!name || !email || !phone || !password) {
      return res.status(400).json({ 
        success: false,
        error: "Missing required fields",
        details: "name, email, phone, password are required"
      });
    }

    if (!cnic || !enrollment_number || !bar_council) {
      return res.status(400).json({ 
        success: false,
        error: "Missing legal documents",
        details: "cnic, enrollment_number, bar_council are required"
      });
    }

    if (!normalizedSpecialization.length) {
      return res.status(400).json({ 
        success: false,
        error: "Invalid specialization",
        details: "specialization must contain at least one value"
      });
    }

    const invalidSpecializations = normalizedSpecialization.filter(
      (item) => !ALLOWED_SPECIALIZATIONS.includes(item)
    );

    if (invalidSpecializations.length) {
      return res.status(400).json({
        success: false,
        error: "Invalid specialization values",
        details: `Unsupported values: ${invalidSpecializations.join(", ")}`
      });
    }

    if (!city || !experience_years || !bio) {
      return res.status(400).json({ 
        success: false,
        error: "Missing professional details",
        details: "city, experience_years, bio are required"
      });
    }

    // Validate email format
    if (!validator.isEmail(email)) {
      return res.status(400).json({ 
        success: false,
        error: "Invalid email format",
        details: email
      });
    }

    // Validate CNIC format
    if (!validateCNIC(cnic)) {
      return res.status(400).json({ 
        success: false,
        error: "Invalid CNIC format",
        details: "CNIC must be in format: XXXXX-XXXXXXX-X"
      });
    }

    // Validate experience years
    if (isNaN(experience_years) || experience_years < 0 || experience_years > 70) {
      return res.status(400).json({ 
        success: false,
        error: "Invalid experience years",
        details: "Must be between 0 and 70"
      });
    }

    // Check required file uploads (cnic_front and license_file are mandatory)
    if (!req.files || !req.files.cnic_front || !req.files.license_file) {
      return res.status(400).json({ 
        success: false,
        error: "Missing document uploads",
        details: "CNIC front photo and License file are required"
      });
    }

    // ===== CHECK DUPLICATES =====
    
    // Check if email already exists
    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(409).json({ 
        success: false,
        error: "Email already registered",
        details: "Please use a different email or login if you already have an account"
      });
    }

    // Check if CNIC already used
    const existingCNIC = await Lawyer.findOne({ cnic });
    if (existingCNIC) {
      return res.status(409).json({ 
        success: false,
        error: "CNIC already registered",
        details: "This CNIC is already associated with a lawyer account"
      });
    }

    // Check if enrollment number already used
    const existingEnrollment = await Lawyer.findOne({ enrollment_number });
    if (existingEnrollment) {
      return res.status(409).json({ 
        success: false,
        error: "Enrollment number already registered",
        details: "This enrollment number is already in use"
      });
    }

    // ===== CREATE USER =====
    
    const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
    
    const user = new User({
      email: email.toLowerCase(),
      password_hash: passwordHash,
      phone: phone,
      profile: { 
        display_name: name 
      },
      role: "lawyer", // Set role as lawyer
      status: "active",
      consent: { 
        tos_accepted: true, 
        tos_accepted_at: new Date() 
      }
    });

    await user.save();

    // Send OTP for email verification (same flow as citizen signup)
    await setAndSendEmailOtp(user);

    // ===== CREATE LAWYER PROFILE =====
    
    const lawyer = new Lawyer({
      user: user._id,
      name,
      email: email.toLowerCase(),
      phone,
      cnic,
      cnic_file: req.files.cnic_front.data,
      cnic_filename: req.files.cnic_front.name,
      cnic_back_file: req.files.cnic_back?.data || null,
      cnic_back_filename: req.files.cnic_back?.name || null,
      enrollment_number,
      bar_council,
      license_file: req.files.license_file.data,
      license_filename: req.files.license_file.name,
      specialization: normalizedSpecialization,
      city,
      experience_years: parseInt(experience_years),
      bio,
      status: "approved",
      verified: true,
      approved_at: new Date(),
      is_visible: true
    });

    await lawyer.save();

    res.status(201).json({
      success: true,
      message: "Application submitted. Please verify the OTP sent to your email before logging in.",
      requires_email_verification: true,
      email: user.email,
      data: {
        user: {
          id: user._id,
          email: user.email,
          name: user.profile.display_name,
          role: user.role
        },
        lawyer: {
          id: lawyer._id,
          applied_at: lawyer.created_at
        },
      }
    });

  } catch (error) {
    console.error("[Lawyer Signup Error]", error);
    res.status(500).json({
      success: false,
      error: "Signup failed",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

export const devLawyerLogin = async (req, res) => {
  try {
    const lawyer = await Lawyer.findOne({
      verified: true,
      status: "approved"
    }).sort({ created_at: 1 });

    if (!lawyer) {
      return res.status(404).json({
        success: false,
        error: "No approved lawyer found for testing"
      });
    }

    const user = await User.findById(lawyer.user);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: "Linked lawyer user not found"
      });
    }

    const accessToken = signJwt(user._id);

    return res.json({
      success: true,
      user: {
        id: user._id,
        email: user.email,
        role: user.role,
        display_name: user.profile?.display_name || lawyer.name
      },
      access_token: accessToken
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: "Failed to create temporary lawyer session",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

// Register as lawyer (old endpoint - for authenticated users)
export const registerLawyer = async (req, res) => {
  return res.status(400).json({
    success: false,
    error: "Deprecated endpoint",
    details: "Use /api/lawyers/signup with required legal documents"
  });
};

// Get all lawyers (public)
export const getLawyers = async (req, res) => {
  try {
    const lawyers = await Lawyer.find({
      verified: true,
      status: "approved",
      is_visible: true
    })
      .sort({ created_at: -1 })
      .select("name specialization city bio experience_years verified is_visible");

    res.json({
      success: true,
      count: lawyers.length,
      data: lawyers.map(sanitizeLawyerListItem)
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Failed to fetch lawyers",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

export const getLawyerProfile = async (req, res) => {
  try {
    const { lawyerId } = req.params;

    const lawyer = await Lawyer.findOne({
      _id: lawyerId,
      verified: true,
      status: "approved",
      is_visible: true
    }).select("name specialization city bio experience_years verified is_visible");

    if (!lawyer) {
      return res.status(404).json({
        success: false,
        error: "Lawyer not found"
      });
    }

    return res.json({
      success: true,
      data: sanitizeLawyerListItem(lawyer)
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: "Failed to fetch lawyer profile",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

// User sends request
export const sendRequest = async (req, res) => {
  try {
    if (req.user?.role === "lawyer") {
      return res.status(403).json({
        success: false,
        error: "Only general users can send lawyer requests"
      });
    }

    const actingUser = req.user || await getOrCreateGuestCitizenUser();
    const userId = actingUser._id;
    const { lawyerId, query } = req.body;

    if (!lawyerId || !query || !query.trim()) {
      return res.status(400).json({
        success: false,
        error: "Missing required fields",
        details: "lawyerId and query are required"
      });
    }

    const lawyer = await Lawyer.findOne({
      _id: lawyerId,
      verified: true,
      status: "approved",
      is_visible: true
    });

    if (!lawyer) {
      return res.status(404).json({
        success: false,
        error: "Selected lawyer is not available"
      });
    }

    const existingPendingRequest = await Connection.findOne({
      user: userId,
      lawyer: lawyerId,
      status: "pending"
    });

    if (existingPendingRequest) {
      return res.status(409).json({
        success: false,
        error: "A pending request already exists for this lawyer"
      });
    }

    const request = await Connection.create({
      user: userId,
      lawyer: lawyerId,
      query: query.trim()
    });

    res.status(201).json({ success: true, data: request });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Failed to send request",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

// Lawyer sees incoming requests
export const getLawyerRequests = async (req, res) => {
  try {
    if (req.user.role !== "lawyer") {
      return res.status(403).json({
        success: false,
        error: "Only lawyers can view incoming requests"
      });
    }

    const lawyer = await Lawyer.findOne({ user: req.user._id });
    if (!lawyer) {
      return res.status(403).json({
        success: false,
        error: "Lawyer profile not found"
      });
    }

    const requests = await Connection.find({ lawyer: lawyer._id })
      .sort({ created_at: -1 })
      .populate("user", "email phone profile.display_name");

    res.json({ success: true, data: requests });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Failed to fetch requests",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

export const respondToRequest = async (req, res) => {
  try {
    const { requestId, status } = req.body;

    if (req.user.role !== "lawyer") {
      return res.status(403).json({
        success: false,
        error: "Only lawyers can respond to requests"
      });
    }

    if (!requestId || !status) {
      return res.status(400).json({
        success: false,
        error: "requestId and status are required"
      });
    }

    if (!["accepted", "rejected"].includes(status)) {
      return res.status(400).json({
        success: false,
        error: "Invalid status",
        details: "status must be accepted or rejected"
      });
    }

    const lawyer = await Lawyer.findOne({ user: req.user._id });
    if (!lawyer) {
      return res.status(403).json({
        success: false,
        error: "Lawyer profile not found"
      });
    }

    const request = await Connection.findOneAndUpdate(
      { _id: requestId, lawyer: lawyer._id },
      { status },
      { new: true }
    );

    if (!request) {
      return res.status(404).json({
        success: false,
        error: "Request not found for this lawyer"
      });
    }

    res.json({ success: true, data: request });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Failed to update request",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
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
    const result = requests.map((requestDoc) => {
      const request = requestDoc.toObject();
      if (request.status !== "accepted" && request.lawyer) {
        request.lawyer.email = null;
        request.lawyer.phone = null;
      }
      return request;
    });

    res.json({ success: true, data: result });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: "Failed to fetch user connections",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

export const getMyLawyerProfile = async (req, res) => {
  try {
    if (req.user.role !== "lawyer") {
      return res.status(403).json({
        success: false,
        error: "Only lawyers can access this resource"
      });
    }

    const lawyer = await Lawyer.findOne({ user: req.user._id }).select(
      "name email phone specialization city experience_years bio verified status is_visible updated_at created_at"
    );

    if (!lawyer) {
      return res.status(404).json({
        success: false,
        error: "Lawyer profile not found"
      });
    }

    return res.json({ success: true, data: lawyer });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: "Failed to fetch lawyer profile",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};

export const updateMyLawyerProfile = async (req, res) => {
  try {
    if (req.user.role !== "lawyer") {
      return res.status(403).json({
        success: false,
        error: "Only lawyers can update this resource"
      });
    }

    const lawyer = await Lawyer.findOne({ user: req.user._id });
    if (!lawyer) {
      return res.status(404).json({
        success: false,
        error: "Lawyer profile not found"
      });
    }

    const {
      name,
      phone,
      city,
      experience_years,
      bio,
      is_visible,
      specialization
    } = req.body;

    if (name !== undefined) lawyer.name = String(name).trim();
    if (phone !== undefined) lawyer.phone = String(phone).trim();
    if (city !== undefined) lawyer.city = String(city).trim();
    if (bio !== undefined) lawyer.bio = String(bio).trim();

    if (experience_years !== undefined) {
      const exp = Number(experience_years);
      if (Number.isNaN(exp) || exp < 0 || exp > 70) {
        return res.status(400).json({
          success: false,
          error: "Invalid experience years",
          details: "Must be between 0 and 70"
        });
      }
      lawyer.experience_years = exp;
    }

    if (specialization !== undefined) {
      const parsedSpecialization = normalizeSpecialization(specialization);
      if (!parsedSpecialization.length) {
        return res.status(400).json({
          success: false,
          error: "specialization must contain at least one value"
        });
      }

      const invalid = parsedSpecialization.filter(
        (item) => !ALLOWED_SPECIALIZATIONS.includes(item)
      );

      if (invalid.length) {
        return res.status(400).json({
          success: false,
          error: "Invalid specialization values",
          details: `Unsupported values: ${invalid.join(", ")}`
        });
      }

      lawyer.specialization = parsedSpecialization;
    }

    if (is_visible !== undefined) {
      lawyer.is_visible = is_visible === true || is_visible === "true";
    }

    lawyer.updated_at = new Date();
    await lawyer.save();

    if (name !== undefined || phone !== undefined) {
      const userUpdate = {};
      if (name !== undefined) {
        userUpdate["profile.display_name"] = lawyer.name;
      }
      if (phone !== undefined) {
        userUpdate.phone = lawyer.phone;
      }

      if (Object.keys(userUpdate).length) {
        await User.updateOne({ _id: req.user._id }, { $set: userUpdate });
      }
    }

    const refreshedLawyer = await Lawyer.findById(lawyer._id).select(
      "name email phone specialization city experience_years bio verified status is_visible updated_at created_at"
    );

    return res.json({
      success: true,
      message: "Lawyer profile updated successfully",
      data: refreshedLawyer
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      error: "Failed to update lawyer profile",
      details: process.env.NODE_ENV === "development" ? error.message : undefined
    });
  }
};