# Mobile Documentation

This folder contains comprehensive documentation for the Mobile app authentication and feature implementation.

## Documentation Files

### [MOBILE_AUTH_IMPLEMENTATION.md](MOBILE_AUTH_IMPLEMENTATION.md)
**Complete mobile UI authentication implementation guide**

- Sign In Screen updates with guest login handler
- Chatbot Screen auth headers and guest call limit enforcement  
- OCR Screen authentication requirements
- Lawyer Profile Screen guest access blocking
- Template Service document generation security checks
- Testing scenarios and deployment checklist
- Integration points with backend endpoints

**Key Topics:**
- Bearer token implementation
- Secure storage key management
- Guest user flow (5 API call limit)
- Authenticated user flow (full access)
- Error messages and user feedback
- UI/UX improvements

**For:** Mobile developers implementing authentication flows, QA testing guest/auth scenarios, users understanding feature restrictions

---

## Related Documentation

- **Backend Implementation**: See [`backend/MD files/BACKEND_AUTH_IMPLEMENTATION.md`](../../backend/MD%20files/BACKEND_AUTH_IMPLEMENTATION.md)
- **System Overview**: See [`AUTHENTICATION_SYSTEM_OVERVIEW.md`](../../AUTHENTICATION_SYSTEM_OVERVIEW.md) at repo root
- **ML Service Notes**: See [`ml-service/md/ML_SERVICE_AUTH_IMPLEMENTATION.md`](../../ml-service/md/ML_SERVICE_AUTH_IMPLEMENTATION.md)

---

## Quick Reference

| Feature | Status | Guest Access | Auth Required |
|---------|:------:|:------------:|:-------------:|
| Chatbot | ✅ | ✅ (5 calls) | Yes |
| Lawyer Connect | ✅ | ❌ | Yes |
| OCR Upload | ✅ | ❌ | Yes |
| Document Generation | ✅ | ❌ | Yes |
| Chat History | ✅ | ❌ | Yes |

---

## Implementation Files Modified

```
lib/
├── screens/
│   ├── signin_screen.dart          ← Guest login metadata storage
│   ├── chatbot_screen.dart         ← Auth headers + guest call tracking
│   ├── ocr_screen.dart             ← Recommended guest blocking
│   └── lawyer_profile_screen.dart  ← Guest feature gating
└── services/
    └── template_service.dart       ← Security checks for document generation
```

---

Generated: April 7, 2026 | Version: 1.0
