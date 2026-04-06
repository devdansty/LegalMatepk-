/**
 * seed-templates.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Standalone script that connects directly to MongoDB and inserts all legal
 * document templates into the "documenttemplates" collection.
 *
 * Usage (from the backend/ folder):
 *   node src/modules/template-generator/seed-templates.js
 *
 * Options (environment variables):
 *   MONGO_URI      – MongoDB connection string (falls back to .env)
 *   SEED_FORCE     – set to "true" to drop and re-insert all templates
 *
 * Add each template object to the TEMPLATES array below, then run the script.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import mongoose from "mongoose";

import DocumentTemplate from "./template.model.js";

// ── Load env vars ──────────────────────────────────────────────────────────
const __dirname = path.dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: path.join(__dirname, "../../../.env") });

// ── Template data ──────────────────────────────────────────────────────────
/**
 * FORMAT FOR EACH TEMPLATE:
 * {
 *   title          : String   – Display name shown in the UI
 *   slug           : String   – URL-safe unique key (auto-derived from title if omitted)
 *   category       : String   – One of: property | family | general | criminal |
 *                                        corporate | nadra | court_application | other
 *   subcategory    : String   – Optional finer tag (e.g. "affidavit", "rent_agreement")
 *   language       : String   – "english" | "urdu" | "bilingual"  (default: "english")
 *   description    : String   – Short description shown in the template list
 *   tags           : [String] – Search keywords
 *   sourceFileName : String   – Original filename for traceability
 *   fields: [                 – Form fields the user must fill in
 *     {
 *       name        : String  – Matches {{placeholder}} in templateContent
 *       label       : String  – Human-readable label in the UI
 *       type        : String  – text | textarea | date | number | select | email | phone
 *       placeholder : String  – Input hint
 *       required    : Boolean – (default true)
 *       options     : [String]– Only for type "select"
 *       order       : Number  – Display order (0-based)
 *     }
 *   ],
 *   templateContent: String   – Full legal text with {{field_name}} placeholders
 * }
 */

const TEMPLATES = [

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 1 – Bahria Town Plot Sale Agreement, Affidavits and Indemnity Bond
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "Bahria Town Plot Sale Agreement, Affidavits and Indemnity Bond Package",
    slug: "bahria-town-plot-sale-agreement",
    category: "property",
    subcategory: "sale_agreement",
    language: "english",
    description:
      "Legal documentation package used during the sale and transfer of a plot in Bahria Town Rawalpindi/Islamabad. Includes purchaser affidavit, seller affidavit, agreement to sell, indemnity bond and undertakings required for property transfer.",
    tags: ["bahria town", "plot sale", "agreement", "affidavit", "indemnity bond", "property transfer"],
    sourceFileName: "aggrement-affidavit-bahria_with_placeholders.docx",
    fields: [
      // ── Purchaser Information ──────────────────────────────────────────────
      { name: "purchaser_name",         label: "Purchaser's Full Name",           type: "text",     required: true, order: 0 },
      { name: "purchaser_father_name",  label: "Purchaser's Father/Guardian Name", type: "text",     required: true, order: 1 },
      { name: "purchaser_nic",          label: "Purchaser's NIC Number",          type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 2 },
      { name: "purchaser_address",      label: "Purchaser's Residential Address", type: "textarea", required: true, order: 3 },
      { name: "purchaser_signature_name", label: "Purchaser's Name (for Signature)", type: "text", required: true, order: 4 },

      // ── Seller Information ─────────────────────────────────────────────────
      { name: "seller_name",            label: "Seller's Full Name",              type: "text",     required: true, order: 5 },
      { name: "seller_father_name",     label: "Seller's Father/Guardian Name",   type: "text",     required: true, order: 6 },
      { name: "seller_nic",             label: "Seller's NIC Number",             type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 7 },
      { name: "seller_address",         label: "Seller's Residential Address",    type: "textarea", required: true, order: 8 },
      { name: "seller_registration_number", label: "Seller's Bahria Registration Number", type: "text", required: true, order: 9 },
      { name: "seller_membership_number", label: "Seller's Membership Number",    type: "text",     required: true, order: 10 },
      { name: "seller_house_number",    label: "Seller's House Number",           type: "text",     required: false, order: 11 },

      // ── Property Details ───────────────────────────────────────────────────
      { name: "plot_number",            label: "Plot Number",                     type: "text",     required: true, order: 12 },
      { name: "plot_phase",             label: "Plot Phase",                      type: "text",     required: true, order: 13 },
      { name: "block_number",           label: "Block Number",                    type: "text",     required: false, order: 14 },
      { name: "phase_number",           label: "Phase Number",                    type: "text",     required: true, order: 15 },
      { name: "plot_size_sqyd",         label: "Plot Size (Sq. Yards)",           type: "number",   required: true, order: 16 },
      { name: "plot_size",              label: "Plot Size (Alternative Format)",  type: "text",     required: false, order: 17 },

      // ── Transaction Details ────────────────────────────────────────────────
      { name: "sale_price_numeric",     label: "Sale Price (Numeric - PKR)",      type: "number",   required: true, order: 18 },
      { name: "sale_price_words",       label: "Sale Price (Words)",              type: "text",     required: true, order: 19 },
      { name: "sale_price_received",    label: "Sale Price Received Amount (PKR)", type: "number",  required: true, order: 20 },
      { name: "penalty_amount",         label: "Penalty Amount (PKR)",            type: "number",   required: false, order: 21 },
      { name: "bahria_letter_number",   label: "Bahria Allotment/Transfer Letter Number", type: "text", required: true, order: 22 },
      { name: "allotment_transfer_letter_number", label: "Original Allotment/Transfer Letter Number", type: "text", required: true, order: 23 },
      { name: "allotment_transfer_letter_date", label: "Allotment/Transfer Letter Date", type: "date", required: true, order: 24 },

      // ── New Purchaser/Transferee ───────────────────────────────────────────
      { name: "new_purchaser_name",     label: "New Purchaser's Name",            type: "text",     required: false, order: 25 },
      { name: "new_purchaser_membership_number", label: "New Purchaser's Membership Number", type: "text", required: false, order: 26 },

      // ── Registration & Undertaking ─────────────────────────────────────────
      { name: "registration_number",    label: "Registration Number",             type: "text",     required: true, order: 27 },
      { name: "undertaking_date",       label: "Undertaking Date",                type: "date",     required: false, order: 28 },

      // ── Agreement Details ──────────────────────────────────────────────────
      { name: "agreement_day",          label: "Agreement Day",                   type: "number",   required: true, order: 29 },
      { name: "agreement_month",        label: "Agreement Month",                 type: "number",   required: true, order: 30 },

      // ── Verification Details ───────────────────────────────────────────────
      { name: "verification_day",       label: "Verification Day",                type: "number",   required: true, order: 31 },
      { name: "verification_month",     label: "Verification Month",              type: "number",   required: true, order: 32 },
      { name: "verification_year",      label: "Verification Year",               type: "number",   required: true, order: 33 },

      // ── Seller Witness Information ─────────────────────────────────────────
      { name: "seller_witness_name",    label: "Seller's Witness Name",           type: "text",     required: false, order: 34 },
      { name: "seller_witness_nic",     label: "Seller's Witness NIC Number",     type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: false, order: 35 },
      { name: "seller_witness_signature", label: "Seller's Witness Signature",    type: "text",     required: false, order: 36 },

      // ── Purchaser Witness Information ──────────────────────────────────────
      { name: "purchaser_witness_name", label: "Purchaser's Witness Name",        type: "text",     required: false, order: 37 },
      { name: "purchaser_witness_nic",  label: "Purchaser's Witness NIC Number",  type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: false, order: 38 },
      { name: "purchaser_witness_signature", label: "Purchaser's Witness Signature", type: "text", required: false, order: 39 },
    ],
    templateContent: `AFFIDAVIT
(by the Purchaser)

I, {{purchaser_name}} son of {{purchaser_father_name}}, NIC No. {{purchaser_nic}}, resident of {{purchaser_address}} in possession of my full faculties and senses and my free will without any coercion or duress do hereby solemnly affirm and declare as under:-

That I am purchasing a Plot No. {{plot_number}}, in phase {{plot_phase}}, which was earlier allotted to Registration No. {{seller_registration_number}} i.e {{seller_name}} son of {{seller_father_name}}, NIC No. {{seller_nic}} resident of {{seller_address}}.

That due to technical reasons and change of design, the said plot presently does not exist on the ground and is only on papers.

That the Bahria Town shall in due course of time make an allotment of an alternative plot in lieu of the said above-mentioned plot.

That I am purchasing the plot on my own risk and accord knowing fully well its implications and liabilities etc.

That I accept this offer of said plot without any coercion and bind myself not to resort to any litigation etc, in future questioning its value on location.

That what is stated above is true to the best of my knowledge and belief.

Deponent
Name {{purchaser_signature_name}}
Signature
Thumb Impression

Verification:
Verified on oath at this {{verification_day}} day of {{verification_month}} year {{verification_year}} that the contents of above affidavit are true and correct to the best of knowledge and belief and nothing has been concealed.

Deponent


UNDERTAKING BY THE PURCHASER

Certified that I am prepared to pay to Bahria Town any variation in Development Charges on demand.

I also undertake to pay on demand any other charges as the management of Bahria Town may decide from time to time.

Signature
Name {{purchaser_name}}
Registration No. {{registration_number}}
Plot No. {{plot_number}}
Block No. {{block_number}}
Phase No. {{phase_number}}
Date: {{undertaking_date}}


AFFIDAVIT BY THE SELLER

I, {{seller_name}} son of {{seller_father_name}}, NIC No. {{seller_nic}} resident of House No. {{seller_house_number}} in possession of my full faculties and senses and my free will without any coercion or duress do hereby solemnly affirm and declare as under:-

That I am a bonafide member of Bahria Town Rawalpindi vide Membership No. {{seller_membership_number}} and I was allotted / transferred a plot of land bearing No. {{plot_number}} in phase {{phase_number}} measuring {{plot_size_sqyd}} Sq. yds in the said Bahria Town.

I hereby return the Original Allotment / Transfer Letter No. {{allotment_transfer_letter_number}} dated {{allotment_transfer_letter_date}} for cancellation and relinquish the above said Allotment of the plot in favour of Bahria Town vide their Membership No. {{seller_membership_number}}.

That having relinquished the plot to the said Bahria Town for allotment to {{new_purchaser_name}}, the plot to be handed over to the said {{new_purchaser_name}} conferring exclusive ownership rights and possession of the plot upon the above said allottee / transferee.

That I affirm and declare that the name of {{new_purchaser_name}} should be entered in the records of the Bahria Town, as the owner of the aforesaid property.

That I solemnly declare that I have no right, title or interest in the said property and {{purchaser_name}} is the exclusive owner of the same since today.

That what is stated above is true to the best of my knowledge and belief.

DEPONENT

VERIFICATION
Verified on Oath at {{purchaser_address}}, that the contents contained in the above said affidavit are true and correct and nothing has been concealed therein.

DEPONENT


AGREEMENT TO SELL A PLOT

AN AGREEMENT made this {{agreement_day}} day of {{agreement_month}}

BETWEEN {{seller_name}} son of {{seller_father_name}}, NIC No. {{seller_nic}} resident of {{seller_address}} (hereinafter called the 'Seller') of the One Part.

AND

{{purchaser_name}} son of {{purchaser_father_name}}, NIC No. {{purchaser_nic}}, resident of {{purchaser_address}} (hereinafter called the 'Purchaser') of the Other Part.

WHEREAS the parties hereto mutually agree as follows:

1. That the 'Seller' will sell and the 'Purchaser' will buy Plot No. {{plot_number}} measuring {{plot_size_sqyd}} Sq. Yds Phase {{phase_number}} in Bahria Town, Rawalpindi / Islamabad at the total consideration of Rs. {{sale_price_numeric}} (Rupees {{sale_price_words}} in words). The Plot stands allotted / transferred vide letter No. {{bahria_letter_number}} Registration No. {{seller_registration_number}} to the "SELLER".

2. That the plot above-mentioned is free from all encumbrances, charges, dues, fees and litigation of all sorts.

3. That the 'Purchaser' has paid and the 'Seller' has accepted and hereby acknowledge the receipt of the entire sale consideration i.e. Rs. {{sale_price_received}}.

4. That the 'Seller' will make himself / herself available and sign all documents, which he is called upon to sign, execute and confirm by the Bahria Town or the 'Purchaser' in connection with the transfer of the said plot in favour of the purchaser.

5. That the 'Seller' has delivered / handed over all original documents of title / allotment / transfer to the Bahria Town to enable Purchaser to finalize sale / transfer in his favour.

6. That if the 'Seller' commits any fault / default in complying with any of the conditions hereinabove mentioned, he / she shall be liable to pay to the purchaser a penalty of a sum of Rs. {{penalty_amount}} as charges / damages.

7. That the terms 'Seller' and the 'Purchaser' hereinbefore used shall include their respective heirs, legal representatives, successors, assigns and nominees.

IN WITNESS WHEREOF the parties have to mentioned have set their respective hands on the date and year above-mentioned.

WITNESSES:-

1. SIG {{seller_witness_signature}}
   NAME {{seller_witness_name}}
   N.I.C No. {{seller_witness_nic}}

(SELLER) {{seller_name}}

2. SIG {{purchaser_witness_signature}}
   NAME {{purchaser_witness_name}}
   N.I.C No. {{purchaser_witness_nic}}

(PURCHASER) {{purchaser_name}}


INDEMNITY BOND (BY THE PURCHASER)

I, {{purchaser_name}} son of {{purchaser_father_name}}, NIC No. {{purchaser_nic}}, resident of {{purchaser_address}} do hereby solemnly affirm and declare as under:-

That I have purchased / obtained allotment of a plot bearing No. {{plot_number}}, measuring {{plot_size_sqyd}}, Phase {{phase_number}}, in Bahria Town, Rawalpindi / Islamabad, on transfer from {{seller_name}} son of {{seller_father_name}}, NIC No. {{seller_nic}} resident of House {{seller_house_number}}, the original allottee.

That I have satisfied myself about the title of the aforesaid seller / transferor in the afore-said plot, and have entered into sale / purchase agreement at my own cost and risk.

That I have undertaken and do hereby indemnify the Bahria Town against all losses, injuries, harms, damages, dues, if any, that may be occasioned to the Bahria Town by the sale / transfer of the aforesaid plot in my favour.

That I further undertake to abide by all the rules and regulations of the C.D.A, R.D.A, Bahria Town, which are presently in force or those to be enforced in future.

(EXECUTANT) {{purchaser_name}}

WITNESSES:-

1. SIG {{purchaser_witness_signature}}
   NAME {{purchaser_witness_name}}
   N.I.C No. {{purchaser_witness_nic}}

2. SIG
   NAME
   N.I.C No.


UNDERTAKING FOR PAYMENT OF CAPITAL VALUE TAX ON VARIATION (BY PURCHASER)

I, {{purchaser_name}} S/o {{purchaser_father_name}}, a Muslim, resident of {{purchaser_address}}, do hereby solemnly declare, affirm and undertake to Pay immediately any variation in Capital Value Tax as and when demanded by the Bahria Town Rawalpindi / Islamabad after working on actual Capital Value Tax. In case of default of payment I hereby clearly understand that the Bahria Town issuing the Transfer letter has the authority and power to cancel it at my cost and risk.

(DEPONENT) {{purchaser_name}}
Name
NIC No. {{purchaser_nic}}

Verification:
Verified on oath at this {{verification_day}} day of {{verification_month}} year {{verification_year}} that the contents of above undertaking are true and correct to the best of knowledge and belief and nothing has been concealed therein.

(DEPONENT) {{purchaser_name}}
Name
NIC No. {{purchaser_nic}}
`,
  },

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 2 – Affidavit for Benami Property Ownership Declaration
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "Affidavit for Benami Property Ownership Declaration",
    slug: "affidavit-benami-property-ownership",
    category: "property",
    subcategory: "benami_declaration",
    language: "english",
    description:
      "Legal affidavit used to declare that a property registered in the deponent's name was actually purchased and financed by another person (usually the father) and that the deponent has no ownership claim over it. The document facilitates future transfer of ownership to the real owner or their nominee.",
    tags: ["benami", "property", "affidavit", "ownership declaration", "transfer"],
    sourceFileName: "Affidavit-BenamiProperty_with_placeholders.docx",
    fields: [
      // ── Deponent Information ────────────────────────────────────────────
      { name: "deponent_name",    label: "Deponent's Full Name",           type: "text",     required: true, order: 0 },
      { name: "spouse_name",      label: "Spouse's Name",                  type: "text",     required: true, order: 1 },
      { name: "parent_name",      label: "Parent's Name",                  type: "text",     required: true, order: 2 },
      { name: "deponent_address", label: "Deponent's Residential Address", type: "textarea", required: true, order: 3 },

      // ── Property Details ────────────────────────────────────────────────
      { name: "khewat_number",    label: "Khewat Number",                 type: "text",     required: true, order: 4 },
      { name: "khatooni_number",  label: "Khatooni Number",               type: "text",     required: true, order: 5 },
      { name: "khasra_number",    label: "Khasra Number",                 type: "text",     required: true, order: 6 },
      { name: "plot_measurement", label: "Plot Measurement (Kanal/Marla)", type: "text",     required: true, order: 7 },
      { name: "mouza_name",       label: "Mouza Name",                     type: "text",     required: true, order: 8 },
      { name: "area_name",        label: "Area/Locality Name",             type: "text",     required: true, order: 9 },

      // ── Real Owner Information ──────────────────────────────────────────
      { name: "father_name",      label: "Real Owner's Name (Father/Guardian)", type: "text", required: true, order: 10 },

      // ── Sale Deed Details ───────────────────────────────────────────────
      { name: "sale_deed_number", label: "Sale Deed Number",              type: "text",     required: true, order: 11 },
      { name: "sale_deed_date",   label: "Sale Deed Date",                type: "date",     required: true, order: 12 },

      // ── Affidavit Details ───────────────────────────────────────────────
      { name: "affidavit_date",   label: "Affidavit Date",                type: "date",     required: true, order: 13 },
      { name: "deponent_signature", label: "Deponent's Signature (Name)", type: "text",     required: true, order: 14 },
    ],
    templateContent: `AFFIDAVIT

I, {{deponent_name}} Husband/Wife of {{spouse_name}} daughter/son of {{parent_name}} resident of {{deponent_address}}, do hereby solemnly affirm and declare as under:

That a Plot bearing Khewat No. {{khewat_number}}, Khatooni No. {{khatooni_number}}, Khasra No. {{khasra_number}}, measuring {{plot_measurement}} Mouza, area {{mouza_name}}, Tehsil and District Rawalpindi was purchased by my real father namely {{father_name}} from his own pocket but transferred the same in my name by way of registered Sale Deed No. {{sale_deed_number}} dated {{sale_deed_date}}, Sub Registrar.

That the entire sale price was paid by my father to the seller and I had no financial contribution towards the purchase of above said plot.

That after purchasing the above said plot, my father built boundary walls, a room, a kitchen, a washroom over the above said plot for my residence from his own pocket and I had no financial contribution towards the construction over the said plot. Currently I am residing in this house.

That as stated above, the sale consideration of said plot was paid by my father and expenses incurred on the construction of said house were borne by my father therefore this house actually belongs to my father and I have no concern whatsoever with the said house nor will claim in future.

I shall be bound to make statement before the concerned authority / officers for transfer of the said house in the name of my father or his nominee, on the request / demand of my father.

I and my other legal heirs have no concern of any kind with the said house.

That the contents of this affidavit are true and correct to the best of my knowledge and belief and nothing has been concealed therefrom.

Dated: {{affidavit_date}}

Deponent
Name {{deponent_signature}}
CNIC No. {{deponent_name}}
`,
  },

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 3 – Affidavit of Property Possession
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "Affidavit of Property Possession",
    slug: "affidavit-property-possession",
    category: "property",
    subcategory: "possession_declaration",
    language: "english",
    description:
      "Legal affidavit used to declare that the deponent is in actual, peaceful and undisputed possession of a specified property. Records property details, method of acquisition, possession history, and confirms that the property is free from disputes or encumbrances.",
    tags: ["possession", "property", "affidavit", "declaration", "encumbrance-free"],
    sourceFileName: "affidavitOfPossession_with_placeholders.docx",
    fields: [
      // ── Deponent Personal Information ───────────────────────────────────
      { name: "deponent_name",         label: "Deponent's Full Name",              type: "text",     required: true, order: 0 },
      { name: "deponent_relation_name", label: "Father's/Husband's Name",         type: "text",     required: true, order: 1 },
      { name: "deponent_age",          label: "Deponent's Age",                    type: "number",   required: true, order: 2 },
      { name: "deponent_cnic",         label: "CNIC Number",                       type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 3 },
      { name: "deponent_profession",   label: "Profession/Occupation",             type: "text",     required: true, order: 4 },
      { name: "deponent_address_line1", label: "Address Line 1",                   type: "text",     required: true, order: 5 },
      { name: "deponent_address_line2", label: "Address Line 2 (City)",            type: "text",     required: true, order: 6 },
      { name: "deponent_address_line3", label: "Address Line 3 (District/Province)", type: "text",   required: true, order: 7 },

      // ── Property Details ────────────────────────────────────────────────
      { name: "property_type",         label: "Type of Property",                  type: "select",   options: ["Residential", "Commercial", "Agricultural", "Industrial", "Mixed Use", "Other"], required: true, order: 8 },
      { name: "property_address",      label: "Property Address/Location",         type: "textarea", required: true, order: 9 },
      { name: "property_area_size",    label: "Property Area/Size",                type: "text",     required: true, order: 10 },
      { name: "registry_document_number", label: "Registry/Title Document Number", type: "text",     required: false, order: 11 },
      { name: "other_property_details", label: "Other Property Details",           type: "textarea", required: false, order: 12 },

      // ── Acquisition & Possession Details ────────────────────────────────
      { name: "property_acquisition_method", label: "Method of Acquisition", type: "select", options: ["Purchase", "Inheritance", "Gift", "Allotment", "Court Decree", "Bequest", "Other"], required: true, order: 13 },
      { name: "possession_since_date",  label: "In Possession Since (Date)",       type: "date",     required: true, order: 14 },

      // ── Affidavit Purpose & Details ─────────────────────────────────────
      { name: "affidavit_purpose",     label: "Purpose of Affidavit",              type: "textarea", placeholder: "e.g., Title verification, Bank loan, Court proceedings", required: true, order: 15 },
      { name: "authority_name",        label: "Authority/Department Name",         type: "text",     placeholder: "e.g., District Court, Revenue Department", required: true, order: 16 },

      // ── Signature & Verification ────────────────────────────────────────
      { name: "deponent_signature",    label: "Deponent's Signature or Name (for Signature Line)", type: "text", required: true, order: 17 },
      { name: "affidavit_date",        label: "Affidavit Date",                    type: "date",     required: true, order: 18 },
      { name: "affidavit_place",       label: "Place of Verification",             type: "text",     required: true, order: 19 },
    ],
    templateContent: `AFFIDAVIT OF POSSESSION

I, {{deponent_name}}, son/daughter/wife of {{deponent_relation_name}}, aged about {{deponent_age}} years, holding CNIC No. {{deponent_cnic}}, by profession {{deponent_profession}}, resident of {{deponent_address_line1}}, {{deponent_address_line2}}, {{deponent_address_line3}}, do hereby solemnly affirm and declare on oath as follows:

That I am the deponent of this affidavit and I am fully competent to swear this affidavit.

That I am in actual, peaceful, and undisputed possession of the following property:

(a) Type of Property: {{property_type}}
(b) Property Address/Location: {{property_address}}
(c) Area/Size: {{property_area_size}}
(d) Registry/Title/Document No.: {{registry_document_number}}
(e) Other Details: {{other_property_details}}

That I acquired the above property through {{property_acquisition_method}} (e.g., purchase, inheritance, gift, allotment, etc.) and have been in continuous possession since {{possession_since_date}}.

That to the best of my knowledge, the said property is free from all encumbrances, liens, or disputes, and no one else has any right, title, or interest in it.

That this affidavit is being made for the purpose of {{affidavit_purpose}} and is to be submitted before/with {{authority_name}} and wherever else required.

That the contents of this affidavit are true and correct to the best of my knowledge and belief.

Signature: {{deponent_signature}}
Name: {{deponent_name}}
CNIC No.: {{deponent_cnic}}
Date: {{affidavit_date}}
Place: {{affidavit_place}}
`,
  },

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 4 – Application for Protection Against Illegal Occupation
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "Application for Protection Against Illegal Occupation of Property",
    slug: "application-protection-illegal-occupation",
    category: "property",
    subcategory: "complaint_application",
    language: "english",
    description:
      "Formal complaint application submitted to the Deputy Commissioner requesting protection against illegal occupation or encroachment of immovable property under the Punjab Protection of Ownership of Immovable Property Ordinance 2025.",
    tags: ["encroachment", "illegal occupation", "property protection", "complaint", "deputy commissioner"],
    sourceFileName: "Application-forOwnershipProtection_with_placeholders.docx",
    fields: [
      // ── Administrative Details ──────────────────────────────────────────
      { name: "city_name",             label: "City/District",                     type: "text",     required: true, order: 0 },

      // ── Applicant Information ───────────────────────────────────────────
      { name: "applicant_name",        label: "Applicant's Full Name",             type: "text",     required: true, order: 1 },
      { name: "applicant_father_name", label: "Father's/Guardian's Name",          type: "text",     required: true, order: 2 },
      { name: "applicant_address",     label: "Applicant's Address",               type: "textarea", required: true, order: 3 },
      { name: "applicant_cnic",        label: "CNIC Number",                       type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 4 },
      { name: "contact_number",        label: "Contact Number",                    type: "phone",    required: true, order: 5 },

      // ── Property Details ────────────────────────────────────────────────
      { name: "property_address",      label: "Property Address/Location",         type: "textarea", required: true, order: 6 },
      { name: "khewat_number",         label: "Khewat Number",                     type: "text",     required: true, order: 7 },
      { name: "khata_number",          label: "Khata Number",                      type: "text",     required: true, order: 8 },
      { name: "khasra_number",         label: "Khasra Number",                     type: "text",     required: true, order: 9 },
      { name: "area_measurement",      label: "Area Measurement (Kanal/Marla/sq.ft)", type: "text",   required: true, order: 10 },

      // ── Respondent/Encroacher Information ───────────────────────────────
      { name: "respondent_name",       label: "Respondent/Encroacher Name",        type: "text",     required: false, placeholder: "Leave blank if unknown", order: 11 },
      { name: "respondent_address",    label: "Respondent/Encroacher Address",     type: "textarea", required: false, placeholder: "Leave blank if unknown", order: 12 },

      // ── Application Signature & Date ────────────────────────────────────
      { name: "applicant_name_signature", label: "Applicant's Name (for Signature Line)", type: "text", required: true, order: 13 },
      { name: "application_date",      label: "Application Date",                  type: "date",     required: true, order: 14 },
    ],
    templateContent: `To,
The Deputy Commissioner,
City: {{city_name}}.

SUBJECT: COMPLAINT AGAINST ILLEGAL OCCUPATION OF IMMOVABLE PROPERTY UNDER THE PUNJAB PROTECTION OF OWNERSHIP OF IMMOVABLE PROPERTY ORDINANCE 2025.

Respected Sir/Madam,

I, {{applicant_name}}, son/daughter of {{applicant_father_name}}, resident of {{applicant_address}}, humbly submit this complaint under the provisions of the Punjab Protection of Ownership of Immovable Property against the illegal possession/actions of the respondent(s) on my property and seeks immediate protection of my lawful ownership rights in respect of my immovable property situated at {{property_address}}.

Having Khewat no. {{khewat_number}}, Khata no. {{khata_number}}, Khasra no. {{khasra_number}} Area Measurement {{area_measurement}}.

It is respectfully stated that I am the lawful owner of the aforementioned property by virtue of sale deed / inheritance / gift, duly registered with the relevant authorities. Despite my legal ownership, certain individuals/entities (name {{respondent_name}} & addresses {{respondent_address}} if you have otherwise write unknown persons) have unlawfully attempted or are attempting to encroach upon, occupy, or interfere with my property. These actions are causing imminent harm, harassment, and the risk of irreversible loss to my lawful property rights.

In view of the above, I request your esteemed office to take immediate action under the Punjab Protection of Ownership of Immovable Property Act, 2025, to:

1. Prevent any unlawful occupation or encroachment on my property.
2. Pass an order for the immediate recovery and restoration of the possession of the aforementioned property to the Applicant.
3. Take prompt legal or administrative action against the perpetrators in accordance with the law.
4. Pass any other orders deemed necessary in the interest of justice.

I humbly emphasize the urgency of this matter, as any delay may result in significant and irreparable damage to my property and lawful rights. I, therefore, request that your office kindly intervene at the earliest to ensure the protection and enforcement of my ownership rights under the law.

I attach herewith all relevant documents, including copy of property ownership documents, registration papers, and also proof of encroachment/unlawful interference, (if you have any) for your kind reference and necessary action.

Your immediate attention and action in this matter will be highly appreciated.

Name & Signature: {{applicant_name_signature}}
Contact No. {{contact_number}}
CNIC No. {{applicant_cnic}}
Date: {{application_date}}
`,
  },

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 5 – General Affidavit Declaration
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "General Affidavit Declaration",
    slug: "general-affidavit-declaration",
    category: "general",
    subcategory: "affidavit",
    language: "english",
    description:
      "A general legal affidavit used to declare statements or facts under oath. The deponent confirms their identity, citizenship, and voluntarily affirms the truth of the statement being declared. Commonly submitted before courts, government offices, or other authorities for various legal or administrative purposes.",
    tags: ["affidavit", "general", "declaration", "oath", "legal statement"],
    sourceFileName: "generalAffidavit_with_placeholders.docx",
    fields: [
      // ── Deponent Personal Information ───────────────────────────────────
      { name: "deponent_name",      label: "Deponent's Full Name",          type: "text",     required: true, order: 0 },
      { name: "deponent_father_name", label: "Father's/Guardian's Name",     type: "text",     required: true, order: 1 },
      { name: "deponent_age",       label: "Age",                            type: "number",   required: true, order: 2 },
      { name: "deponent_cnic",      label: "CNIC Number",                    type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 3 },
      { name: "deponent_address",   label: "Residential Address",            type: "textarea", required: true, order: 4 },

      // ── Declaration Details ────────────────────────────────────────────
      { name: "affidavit_statement", label: "Statement/Facts to Declare",    type: "textarea", placeholder: "Enter the main statement or facts being declared", required: true, order: 5 },

      // ── Purpose & Authority ────────────────────────────────────────────
      { name: "affidavit_purpose",   label: "Purpose of Affidavit",         type: "textarea", placeholder: "e.g., For bank loan, court proceedings, government application", required: true, order: 6 },
      { name: "authority_name",      label: "Authority/Department Name",    type: "text",     placeholder: "e.g., District Court, Revenue Department, Bank", required: true, order: 7 },

      // ── Signature & Date ───────────────────────────────────────────────
      { name: "affidavit_date",      label: "Affidavit Date",               type: "date",     required: true, order: 8 },
      { name: "affidavit_place",     label: "Place of Affidavit",           type: "text",     required: true, order: 9 },
    ],
    templateContent: `GENERAL AFFIDAVIT

I, {{deponent_name}}, son/daughter of {{deponent_father_name}}, aged about {{deponent_age}} years, holding CNIC No. {{deponent_cnic}}, resident of {{deponent_address}}, do hereby solemnly affirm and declare on oath as under:

That I am a Pakistani citizen and the above-mentioned particulars are true and correct.

That I am fully competent to swear this affidavit and I am making this declaration voluntarily and without any pressure.

That the facts stated herein are based on my personal knowledge and belief and are true and correct.

That {{affidavit_statement}}.

That this affidavit is made for the purpose of {{affidavit_purpose}} and to be submitted before {{authority_name}}.

That I undertake that if any part of this affidavit is found incorrect, I shall be liable under the relevant laws of Pakistan.

That the contents of this affidavit are true and correct to the best of my knowledge and belief and nothing has been concealed therefrom.

DEPONENT

Signature: ___________________________
Name: {{deponent_name}}
CNIC No.: {{deponent_cnic}}
Date: {{affidavit_date}}
Place: {{affidavit_place}}
`,
  },

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 6 – Property Ownership Affidavit
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "Property Ownership Affidavit",
    slug: "property-ownership-affidavit",
    category: "property",
    subcategory: "ownership_declaration",
    language: "english",
    description:
      "Legal affidavit used to formally declare lawful ownership and possession of a property. Confirms property details, acquisition method, and states that the property is free from disputes or encumbrances. Typically submitted before courts, government authorities, or administrative bodies when proof of ownership is required.",
    tags: ["property", "ownership", "affidavit", "declaration", "encumbrance-free"],
    sourceFileName: "propertyOwnershipAffidavit_with_placeholders.docx",
    fields: [
      // ── Deponent Personal Information ───────────────────────────────────
      { name: "deponent_name",         label: "Deponent's Full Name",              type: "text",     required: true, order: 0 },
      { name: "deponent_relation_name", label: "Father's/Husband's Name",         type: "text",     required: true, order: 1 },
      { name: "deponent_age",          label: "Deponent's Age",                    type: "number",   required: true, order: 2 },
      { name: "deponent_cnic",         label: "CNIC Number",                       type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 3 },
      { name: "deponent_profession",   label: "Profession/Occupation",             type: "text",     required: true, order: 4 },
      { name: "deponent_address_line1", label: "Address Line 1",                   type: "text",     required: true, order: 5 },
      { name: "deponent_address_line2", label: "Address Line 2 (City)",            type: "text",     required: true, order: 6 },
      { name: "deponent_address_line3", label: "Address Line 3 (District/Province)", type: "text",   required: true, order: 7 },

      // ── Property Details ────────────────────────────────────────────────
      { name: "property_type",         label: "Type of Property",                  type: "select",   options: ["Residential", "Commercial", "Agricultural", "Industrial", "Mixed Use", "Other"], required: true, order: 8 },
      { name: "property_address",      label: "Property Address/Location",         type: "textarea", required: true, order: 9 },
      { name: "property_area_size",    label: "Property Area/Size",                type: "text",     required: true, order: 10 },
      { name: "registry_document_number", label: "Registry/Title Document Number", type: "text",     required: false, order: 11 },
      { name: "other_property_details", label: "Other Property Details",           type: "textarea", required: false, order: 12 },

      // ── Acquisition Method ──────────────────────────────────────────────
      { name: "property_acquisition_method", label: "Method of Acquisition", type: "select", options: ["Purchase", "Inheritance", "Gift", "Allotment", "Court Decree", "Bequest", "Other"], required: true, order: 13 },

      // ── Affidavit Purpose & Details ─────────────────────────────────────
      { name: "affidavit_purpose",     label: "Purpose of Affidavit",              type: "textarea", placeholder: "e.g., Title verification, Bank loan, Court proceedings", required: true, order: 14 },
      { name: "authority_name",        label: "Authority/Department Name",         type: "text",     placeholder: "e.g., District Court, Revenue Department", required: true, order: 15 },

      // ── Signature & Verification ────────────────────────────────────────
      { name: "deponent_signature",    label: "Deponent's Signature or Name (for Signature Line)", type: "text", required: true, order: 16 },
      { name: "affidavit_date",        label: "Affidavit Date",                    type: "date",     required: true, order: 17 },
      { name: "affidavit_place",       label: "Place of Verification",             type: "text",     required: true, order: 18 },
    ],
    templateContent: `PROPERTY OWNERSHIP AFFIDAVIT

I, {{deponent_name}}, son/daughter/wife of {{deponent_relation_name}}, aged about {{deponent_age}} years, holding CNIC No. {{deponent_cnic}}, by profession {{deponent_profession}}, resident of {{deponent_address_line1}}, {{deponent_address_line2}}, {{deponent_address_line3}}, do hereby solemnly affirm and declare on oath as follows:

That I am the deponent of this affidavit and I am fully competent to swear this affidavit.

That I am the lawful owner of the following property:

(a) Type of Property: {{property_type}}
(b) Property Address/Location: {{property_address}}
(c) Area/Size: {{property_area_size}}
(d) Registry/Title/Document No.: {{registry_document_number}}
(e) Other Details: {{other_property_details}}

That the above property was acquired by me through {{property_acquisition_method}} (e.g., purchase, inheritance, gift, allotment, etc.) and is free from all encumbrances, liens, or disputes to the best of my knowledge.

That I am in peaceful possession of the said property and no one else has any right, title, or interest in it.

That this affidavit is being made for the purpose of {{affidavit_purpose}} and is to be submitted before/with {{authority_name}} and wherever else required.

That the contents of this affidavit are true and correct to the best of my knowledge and belief.

Signature: {{deponent_signature}}
Name: {{deponent_name}}
CNIC No.: {{deponent_cnic}}
Date: {{affidavit_date}}
Place: {{affidavit_place}}
`,
  },

  // ══════════════════════════════════════════════════════════════════════════
  // TEMPLATE 7 – Residential House Rent Agreement
  // ══════════════════════════════════════════════════════════════════════════
  {
    title: "Residential House Rent Agreement",
    slug: "residential-house-rent-agreement",
    category: "property",
    subcategory: "rental_agreement",
    language: "english",
    description:
      "Legal rental agreement executed between a landlord and tenant for the lease of a residential property. Records landlord and tenant details, rent amount, security deposit, tenancy duration, and terms governing the use and possession of the property during the tenancy period.",
    tags: ["rent", "lease", "agreement", "residential", "landlord", "tenant"],
    sourceFileName: "Rent-Agreement_with_placeholders.docx",
    fields: [
      // ── Agreement Header ────────────────────────────────────────────────
      { name: "agreement_title",       label: "Agreement Title",                   type: "text",     required: true, order: 0 },
      { name: "agreement_date",        label: "Agreement Date",                    type: "date",     required: true, order: 1 },

      // ── Landlord Information ────────────────────────────────────────────
      { name: "landlord_name",         label: "Landlord's Full Name",              type: "text",     required: true, order: 2 },
      { name: "landlord_father_name",  label: "Landlord's Father's Name",          type: "text",     required: true, order: 3 },
      { name: "landlord_address",      label: "Landlord's Address",                type: "textarea", required: true, order: 4 },
      { name: "landlord_cnic",         label: "Landlord's CNIC Number",            type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 5 },

      // ── Tenant Information ──────────────────────────────────────────────
      { name: "tenant_name",           label: "Tenant's Full Name",                type: "text",     required: true, order: 6 },
      { name: "tenant_father_name",    label: "Tenant's Father's Name",            type: "text",     required: true, order: 7 },
      { name: "tenant_address",        label: "Tenant's Address",                  type: "textarea", required: true, order: 8 },
      { name: "tenant_cnic",           label: "Tenant's CNIC Number",              type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: true, order: 9 },

      // ── Property Details ────────────────────────────────────────────────
      { name: "house_address",         label: "House Address",                     type: "textarea", required: true, order: 10 },

      // ── Rent Details ────────────────────────────────────────────────────
      { name: "monthly_rent",          label: "Monthly Rent (Numeric - PKR)",      type: "number",   required: true, order: 11 },
      { name: "monthly_rent_words",    label: "Monthly Rent (Words)",              type: "text",     required: true, order: 12 },
      { name: "rent_payment_day",      label: "Rent Payment Day (within X days)",  type: "number",   placeholder: "e.g., 5", required: true, order: 13 },

      // ── Security Deposit ────────────────────────────────────────────────
      { name: "security_deposit_amount", label: "Security Deposit (Numeric - PKR)", type: "number",  required: true, order: 14 },
      { name: "security_deposit_words",  label: "Security Deposit (Words)",        type: "text",     required: true, order: 15 },

      // ── Tenancy Duration ────────────────────────────────────────────────
      { name: "tenancy_duration",      label: "Tenancy Duration",                  type: "text",     placeholder: "e.g., 1 year, 6 months", required: true, order: 16 },
      { name: "tenancy_start_date",    label: "Tenancy Start Date",                type: "date",     required: true, order: 17 },
      { name: "tenancy_end_date",      label: "Tenancy End Date",                  type: "date",     required: true, order: 18 },

      // ── Landlord Signature ──────────────────────────────────────────────
      { name: "landlord_signature",    label: "Landlord's Signature/Name",         type: "text",     required: true, order: 19 },

      // ── Tenant Signature ────────────────────────────────────────────────
      { name: "tenant_signature",      label: "Tenant's Signature/Name",           type: "text",     required: true, order: 20 },

      // ── Witness 1 Information ───────────────────────────────────────────
      { name: "witness1_name",         label: "Witness 1 Name",                    type: "text",     required: false, order: 21 },
      { name: "witness1_father_name",  label: "Witness 1 Father's Name",           type: "text",     required: false, order: 22 },
      { name: "witness1_cnic",         label: "Witness 1 CNIC Number",             type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: false, order: 23 },
      { name: "witness1_signature",    label: "Witness 1 Signature/Name",          type: "text",     required: false, order: 24 },

      // ── Witness 2 Information ───────────────────────────────────────────
      { name: "witness2_name",         label: "Witness 2 Name",                    type: "text",     required: false, order: 25 },
      { name: "witness2_father_name",  label: "Witness 2 Father's Name",           type: "text",     required: false, order: 26 },
      { name: "witness2_cnic",         label: "Witness 2 CNIC Number",             type: "text",     placeholder: "XXXXX-XXXXXXX-X", required: false, order: 27 },
      { name: "witness2_signature",    label: "Witness 2 Signature/Name",          type: "text",     required: false, order: 28 },
    ],
    templateContent: `RENT AGREEMENT OF HOUSE

This rent agreement of {{agreement_title}} is being executed on dated {{agreement_date}} between {{landlord_name}} son of {{landlord_father_name}} R/O {{landlord_address}} (hereinafter called as LORD-FIRST PARTY)

AND

{{tenant_name}} son of {{tenant_father_name}} R/O {{tenant_address}} (hereinafter called the NT-ND PARTY)

WHEREAS, the said first party is the absolute owner in possession of {{house_address}} and has agreed to let out the said House on monthly rent basis to the Tenant and Tenant has agreed on the same, with the following terms and conditions.

TERMS AND CONDITIONS:

1. That the rent of the above-stated House has been fixed as Rs. {{monthly_rent}} /- (Rupees {{monthly_rent_words}} only) per month which will always be paid in advance within {{rent_payment_day}} day of every month, against a receipt in writing. Also a refundable Security Deposit of Rs. {{security_deposit_amount}} /- (Rupees {{security_deposit_words}} only) has been paid from the Second Party to first party which is refundable at the time of vacation of the said House by the Second Party adjusting therewith unpaid utility bills, unpaid monthly rent, etc., if any.

2. That the tenancy period is for {{tenancy_duration}} i.e from {{tenancy_start_date}} to {{tenancy_end_date}}.

3. That one month's notice from either party for the vacation of the said House is mandatory, e.g. if Second Party wishes to vacate the said House and hand over to the First Party or the First Party wishes to get the said House vacated from the Second Party.

4. That the Second Party is not allowed to make any sort of change in the structure of the House without the written prior approval of the First Party.

5. That the Second Party will utilize the House only and only for the residential purposes within framework of the law and rule of the Islamic Republic of Pakistan. Any illegal activity detected would tend to revocation of the instant Rent Agreement and the House will be got vacated from Second Party without serving upon him any notice in writing.

6. That the Second Party will not sub-let the House wholly or partially.

7. That the possession of the House will physically be handed over to the First Party on the expiry of the instant agreement.

8. That the Second Party will hand over the possession of the House back to the First Party in the condition it was given to him. He will be fully responsible for repair or replacement of any wear and tear in the House.

9. That the Second Party will be solely responsible for the payment of all sort of Utility Bills i.e. Electricity, Gas, Water, etc., and give back the paid bills to the First Party.

10. That the First Party or his agent(s) shall have the right at all reasonable times during the term of this Rent Agreement and any renewal of this Lease Agreement to enter the said House for the purpose of inspecting the premises and / or making any repairs to the premises or other item as required under this Rent Agreement.

11. That breach of any of the above terms and conditions will tend to vacation of the House by the Second Party without serving any kind of notice.

IN WITNESS WHEREOF, this Tenancy Agreement has been drafted, read and understood by both the parties and signed before the presents on the date, month and the year mentioned above.

LANDLORD (FIRST PARTY):
Signature: {{landlord_signature}}
Name: {{landlord_name}}
CNIC No. {{landlord_cnic}}

TENANT (SECOND PARTY):
Signature: {{tenant_signature}}
Name: {{tenant_name}}
CNIC No. {{tenant_cnic}}

WITNESS 1:
Signature: {{witness1_signature}}
Name: {{witness1_name}}
Son of {{witness1_father_name}}
CNIC No. {{witness1_cnic}}

WITNESS 2:
Signature: {{witness2_signature}}
Name: {{witness2_name}}
Son of {{witness2_father_name}}
CNIC No. {{witness2_cnic}}
`,
  },

];

// ── Seed runner ────────────────────────────────────────────────────────────

async function seed() {
  const uri = process.env.MONGO_URI;
  if (!uri) {
    console.error(
      "❌  MONGO_URI is not set.  Create / update backend/.env and try again."
    );
    process.exit(1);
  }

  console.log("🔌  Connecting to MongoDB …");
  await mongoose.connect(uri);
  console.log(`✅  Connected to database: ${mongoose.connection.name}`);

  if (process.env.SEED_FORCE === "true") {
    console.log("⚠️   SEED_FORCE=true – dropping existing documenttemplates …");
    await DocumentTemplate.deleteMany({});
    console.log("    Collection cleared.");
  }

  let inserted = 0;
  let skipped = 0;

  for (const tpl of TEMPLATES) {
    try {
      const slug = tpl.slug || tpl.title.toLowerCase().replace(/[^a-z0-9\s-]/g, "").trim().replace(/\s+/g, "-");

      const exists = await DocumentTemplate.findOne({ slug });
      if (exists) {
        console.log(`  ⏭   Skipped (already exists): ${slug}`);
        skipped++;
        continue;
      }

      await DocumentTemplate.create({ ...tpl, slug });
      console.log(`  ✅  Inserted: ${slug}`);
      inserted++;
    } catch (err) {
      console.error(`  ❌  Failed to insert "${tpl.title}":`, err.message);
    }
  }

  console.log(
    `\n📦  Seed complete – ${inserted} inserted, ${skipped} skipped.`
  );
  await mongoose.disconnect();
  process.exit(0);
}

seed().catch((err) => {
  console.error("Fatal seed error:", err);
  process.exit(1);
});
