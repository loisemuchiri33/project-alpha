#!/usr/bin/env python3
"""Generate ZENI Letter of No Objection and related CBK cover materials (PDF)."""

from pathlib import Path
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, HRFlowable, KeepTogether,
)

OUT = Path("/home/user/zeni/docs/ZENI_Letter_of_No_Objection.pdf")
GREEN = HexColor("#0B6E4F")
GREEN_DARK = HexColor("#085540")
LIGHT = HexColor("#F7FAFC")
LINE = HexColor("#CBD5E0")
MUTED = HexColor("#718096")
TEXT = HexColor("#1A202C")

TODAY = datetime.now().strftime("%d %B %Y")


def S():
    b = getSampleStyleSheet()
    return {
        "letterhead": ParagraphStyle(
            "letterhead", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=18, textColor=GREEN_DARK, alignment=TA_CENTER, leading=22,
        ),
        "tag": ParagraphStyle(
            "tag", parent=b["Normal"], fontName="Helvetica",
            fontSize=9, textColor=GREEN, alignment=TA_CENTER, leading=12,
        ),
        "meta": ParagraphStyle(
            "meta", parent=b["Normal"], fontName="Helvetica",
            fontSize=9, textColor=MUTED, alignment=TA_CENTER, leading=12,
        ),
        "ref": ParagraphStyle(
            "ref", parent=b["Normal"], fontName="Helvetica",
            fontSize=10, textColor=TEXT, leading=14, spaceAfter=2,
        ),
        "date_r": ParagraphStyle(
            "date_r", parent=b["Normal"], fontName="Helvetica",
            fontSize=10, textColor=TEXT, alignment=TA_RIGHT, leading=14,
        ),
        "title": ParagraphStyle(
            "title", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=12, textColor=GREEN_DARK, alignment=TA_CENTER,
            spaceBefore=10, spaceAfter=12, leading=16,
        ),
        "body": ParagraphStyle(
            "body", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, alignment=TA_JUSTIFY,
            leading=15, spaceAfter=8,
        ),
        "body_l": ParagraphStyle(
            "body_l", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, alignment=TA_LEFT,
            leading=15, spaceAfter=6,
        ),
        "sign": ParagraphStyle(
            "sign", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, leading=14, spaceAfter=2,
        ),
        "small": ParagraphStyle(
            "small", parent=b["Normal"], fontName="Helvetica-Oblique",
            fontSize=8, textColor=MUTED, alignment=TA_JUSTIFY, leading=11,
        ),
        "h2": ParagraphStyle(
            "h2", parent=b["Heading2"], fontName="Helvetica-Bold",
            fontSize=12, textColor=GREEN_DARK, spaceBefore=8, spaceAfter=8,
        ),
        "bullet": ParagraphStyle(
            "bullet", parent=b["Normal"], fontName="Helvetica",
            fontSize=10, textColor=TEXT, leftIndent=14, leading=14, spaceAfter=3,
        ),
        "banner": ParagraphStyle(
            "banner", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=11, textColor=white, alignment=TA_CENTER, leading=14,
        ),
        "toc": ParagraphStyle(
            "toc", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, leading=16, spaceAfter=4,
        ),
    }


def header_block(s, subtitle=""):
    elems = []
    elems.append(Paragraph("ZENI LIMITED", s["letterhead"]))
    elems.append(Paragraph("Smart Loans. Secure Future.", s["tag"]))
    elems.append(Paragraph(
        "Proposed Digital Credit Provider &nbsp;|&nbsp; Republic of Kenya",
        s["meta"],
    ))
    if subtitle:
        elems.append(Spacer(1, 4))
        elems.append(Paragraph(subtitle, s["meta"]))
    elems.append(Spacer(1, 4))
    elems.append(HRFlowable(width="100%", thickness=2, color=GREEN, spaceAfter=2))
    elems.append(HRFlowable(width="100%", thickness=0.5, color=GREEN_DARK, spaceBefore=0, spaceAfter=10))
    return elems


def footer_note(s, page_label):
    return Paragraph(
        f"<i>Confidential — {page_label}. Draft for legal counsel review before execution. "
        f"Placeholders in [SQUARE BRACKETS] must be completed. Generated {TODAY}.</i>",
        s["small"],
    )


def page_cover(s):
    e = []
    band = Table(
        [[Paragraph("REGULATORY DOCUMENT PACK", s["banner"])],
         [Paragraph("LETTER OF NO OBJECTION & RELATED INSTRUMENTS", s["banner"])],
         [Spacer(1, 6)],
         [Paragraph(
             "In support of engagement with the<br/>CENTRAL BANK OF KENYA",
             ParagraphStyle("c", parent=s["banner"], fontName="Helvetica", fontSize=10),
         )]],
        colWidths=[170 * mm],
    )
    band.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), GREEN_DARK),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
        ("TOPPADDING", (0, 0), (-1, 0), 28),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 28),
    ]))
    e.append(Spacer(1, 25 * mm))
    e.append(band)
    e.append(Spacer(1, 14 * mm))
    e.append(Paragraph("Contents of this pack", s["h2"]))
    for line in [
        "Document A — Shareholder / Sponsor Letter of No Objection (LONO)",
        "Document B — Board Resolution Authorising Application and LONO",
        "Document C — Cover Transmittal Letter to the Central Bank of Kenya",
        "Document D — Completion Checklist & Signing Guidance",
    ]:
        e.append(Paragraph(f"• {line}", s["toc"]))
    e.append(Spacer(1, 10 * mm))
    meta = [
        ["Applicant", "ZENI Limited (proposed / in formation)"],
        ["Subject matter", "Digital credit provider authorisation support"],
        ["Classification", "Confidential — Regulatory"],
        ["Status", "DRAFT — for Kenya counsel review before wet-ink / e-sign"],
        ["Version", f"1.0  |  {TODAY}"],
    ]
    cells = [[Paragraph(f"<b>{a}</b>", s["body_l"]), Paragraph(b, s["body_l"])] for a, b in meta]
    t = Table(cells, colWidths=[45 * mm, 125 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), LIGHT),
        ("BOX", (0, 0), (-1, -1), 0.5, LINE),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ]))
    e.append(t)
    e.append(Spacer(1, 10 * mm))
    e.append(Paragraph(
        "Purpose. A Letter of No Objection (LONO) is commonly required in Kenyan licensing packs "
        "to evidence that a significant shareholder, parent company, related regulated entity, or "
        "other interested party has no objection to (i) the formation and ownership structure of "
        "the applicant, (ii) the pursuit of Central Bank of Kenya authorisation as a Digital Credit "
        "Provider, and/or (iii) the use of a name, brand, technology, or group affiliation. This "
        "pack provides execution-ready drafts reflecting market practice. It is not a substitute "
        "for advice from Kenya-qualified advocates or for any form prescribed by the CBK.",
        s["body"],
    ))
    e.append(PageBreak())
    return e


def doc_a_lono(s):
    e = []
    e += header_block(s)
    e.append(Paragraph(f"Our Ref: ZENI/LONO/SHA/[●●●]/{datetime.now().year}", s["ref"]))
    e.append(Paragraph(f"Date: {TODAY}", s["ref"]))
    e.append(Spacer(1, 6))
    e.append(Paragraph("<b>TO WHOM IT MAY CONCERN</b>", s["body_l"]))
    e.append(Paragraph(
        "<b>The Governor</b><br/>"
        "Central Bank of Kenya<br/>"
        "Haile Selassie Avenue<br/>"
        "P.O. Box 60000 — 00200<br/>"
        "Nairobi, Kenya",
        s["body_l"],
    ))
    e.append(Paragraph(
        "(and to such licensing / supervisory officers as may be concerned)",
        s["small"],
    ))
    e.append(Spacer(1, 6))
    e.append(Paragraph(
        "RE: LETTER OF NO OBJECTION — PROPOSED DIGITAL CREDIT PROVIDER AUTHORISATION<br/>"
        "OF ZENI LIMITED",
        s["title"],
    ))
    e.append(Paragraph("1. Introduction", s["h2"]))
    e.append(Paragraph(
        "We, <b>[FULL LEGAL NAME OF SHAREHOLDER / SPONSOR / PARENT ENTITY]</b>, a company / "
        "person duly existing under the laws of <b>[JURISDICTION]</b>, with registered office at "
        "<b>[ADDRESS]</b> (the “<b>Sponsor</b>”), write in relation to <b>ZENI Limited</b> "
        "(the “<b>Company</b>”), a company [incorporated / to be incorporated] under the Companies "
        "Act of Kenya for the purpose of carrying on digital credit business in the Republic of Kenya.",
        s["body"],
    ))
    e.append(Paragraph(
        "The Sponsor is the [proposed] holder of <b>[●●]%</b> of the issued share capital of the "
        "Company (or otherwise a significant controller as described in the application pack).",
        s["body"],
    ))
    e.append(Paragraph("2. Declarations of No Objection", s["h2"]))
    e.append(Paragraph(
        "The Sponsor hereby irrevocably and unconditionally confirms, acknowledges and declares that:",
        s["body"],
    ))
    for b in [
        "It has <b>no objection</b> to the incorporation, ownership structure, branding and intended "
        "business of the Company as a digital credit provider in Kenya.",
        "It has <b>no objection</b> to the Company preparing, submitting and prosecuting an application "
        "to the <b>Central Bank of Kenya (“CBK”)</b> for authorisation to conduct digital credit "
        "business under the applicable Digital Credit Provider regulatory framework, regulations, "
        "circulars and guidance in force.",
        "It has <b>no objection</b> to the Company’s use of the name, mark and brand “ZENI” and the "
        "tagline “Smart Loans. Secure Future.” in connection with such regulated business, subject "
        "to any separate trademark licences being put in place on arm’s-length terms where required.",
        "It has <b>no objection</b> to the appointment of the proposed directors and senior officers "
        "named in the CBK fit-and-proper filings (as updated from time to time), and confirms it will "
        "not take funded or unfunded action calculated to frustrate effectiveness of those appointments "
        "without prior notice to the Company and, where required, to CBK.",
        "It has <b>no objection</b> to the Company opening and operating bank accounts, contracting "
        "with mobile money / payment service providers (including M-Pesa arrangements), credit "
        "reference bureaux, and other material vendors necessary for regulated operations, subject "
        "to Board governance of the Company.",
        "The funds to be invested or already invested by the Sponsor in the Company are from "
        "legitimate sources; the Sponsor will provide source-of-funds / source-of-wealth evidence "
        "to CBK and to the Company’s bankers upon reasonable request.",
        "There is <b>no pending or, to the Sponsor’s knowledge, threatened litigation, regulatory "
        "action, or contractual restriction</b> that would prohibit the Sponsor from giving this "
        "Letter or prohibit the Company from seeking CBK authorisation.",
        "The Sponsor will <b>not withdraw capital</b>, declare dividends, or extract value from the "
        "Company in a manner that would cause the Company to breach minimum capital or liquidity "
        "expectations applicable to digital credit providers, without Board approval of the Company "
        "and any required supervisory notification.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Paragraph("3. Support and Cooperation", s["h2"]))
    e.append(Paragraph(
        "The Sponsor undertakes to cooperate reasonably with the Company and with CBK in connection "
        "with the application, including timely completion of fit-and-proper questionnaires, "
        "disclosure of ultimate beneficial ownership, and provision of corporate documents "
        "civil/criminal clearance extracts, and financial information relating to the Sponsor "
        "as may lawfully be requested.",
        s["body"],
    ))
    e.append(Paragraph("4. Limitations", s["h2"]))
    e.append(Paragraph(
        "This Letter is given solely for the purpose of supporting the Company’s regulatory "
        "engagement with CBK and related professional advisors. It does not constitute a guarantee "
        "of the Company’s liabilities, a comfort letter to creditors, or an undertaking to inject "
        "unlimited capital, except as may be separately documented in a capital support deed "
        "(if any).",
        s["body"],
    ))
    e.append(Paragraph("5. Governing Understanding", s["h2"]))
    e.append(Paragraph(
        "This Letter shall be interpreted in a manner consistent with Kenyan financial-sector "
        "regulatory practice. The Sponsor acknowledges that CBK may place reliance on the truthfulness "
        "of the statements herein in assessing the Company’s application.",
        s["body"],
    ))
    e.append(Paragraph("6. Authority", s["h2"]))
    e.append(Paragraph(
        "The signatory below is duly authorised to issue this Letter on behalf of the Sponsor, "
        "pursuant to [board resolution / power of attorney / personal capacity as individual "
        "shareholder] dated <b>[DATE]</b>.",
        s["body"],
    ))
    e.append(Spacer(1, 4))
    e.append(Paragraph(
        "Accordingly, we <b>CONFIRM THAT WE HAVE NO OBJECTION</b> to the matters set out above.",
        s["body"],
    ))
    e.append(Spacer(1, 8))
    e.append(Paragraph("Yours faithfully,", s["sign"]))
    e.append(Paragraph("<b>FOR AND ON BEHALF OF THE SPONSOR</b>", s["sign"]))
    e.append(Spacer(1, 16))
    e.append(Paragraph("________________________________________", s["sign"]))
    e.append(Paragraph("<b>Name:</b> [FULL NAME]", s["sign"]))
    e.append(Paragraph("<b>Designation:</b> [Director / Authorised Signatory / Individual Shareholder]", s["sign"]))
    e.append(Paragraph("<b>Entity (if applicable):</b> [LEGAL NAME]", s["sign"]))
    e.append(Paragraph("<b>ID / Passport No.:</b> [●●●●●●●●]", s["sign"]))
    e.append(Paragraph("<b>Date:</b> ______________________", s["sign"]))
    e.append(Spacer(1, 10))
    e.append(Paragraph("<b>In the presence of (witness / commissioner where required):</b>", s["sign"]))
    e.append(Spacer(1, 12))
    e.append(Paragraph("________________________________________", s["sign"]))
    e.append(Paragraph("Name / Signature / Designation / Date", s["sign"]))
    e.append(Spacer(1, 10))
    e.append(Paragraph(
        "Company stamp / seal (if applicable): ______________________",
        s["sign"],
    ))
    e.append(Spacer(1, 12))
    e.append(footer_note(s, "Document A — Shareholder Letter of No Objection"))
    e.append(PageBreak())
    return e


def doc_b_board(s):
    e = []
    e += header_block(s, "Board Resolution — Extract Form")
    e.append(Paragraph(
        "EXTRACT OF RESOLUTIONS OF THE BOARD OF DIRECTORS OF<br/>ZENI LIMITED",
        s["title"],
    ))
    e.append(Paragraph(
        "At a meeting of the Board of Directors of <b>ZENI Limited</b> (the “Company”) held at "
        "<b>[VENUE / VIDEO]</b> on <b>[DATE]</b>, at which a quorum was present and acting "
        "throughout, the following resolutions were duly passed:",
        s["body"],
    ))
    e.append(Paragraph("<b>IT WAS RESOLVED THAT:</b>", s["body_l"]))
    e.append(Paragraph(
        "<b>Resolution 1 — Regulatory application.</b> The Company be and is hereby authorised "
        "to prepare and submit an application to the Central Bank of Kenya for authorisation to "
        "operate as a Digital Credit Provider, and to file all supporting documents including the "
        "Business Plan, policies, fit-and-proper filings, and capital evidence.",
        s["body"],
    ))
    e.append(Paragraph(
        "<b>Resolution 2 — Letters of No Objection.</b> The Company request and accept Letters of "
        "No Objection from its significant shareholders / sponsors substantially in the form of "
        "Document A of the regulatory pack (with such amendments as legal counsel may advise), "
        "and the Company Secretary be authorised to table executed LONO originals with the CBK pack.",
        s["body"],
    ))
    e.append(Paragraph(
        "<b>Resolution 3 — Authorised signatories.</b> Any two (2) Directors, or one (1) Director "
        "together with the Chief Executive Officer, be and are hereby authorised to execute "
        "applications, declarations, undertakings and correspondence with CBK and professional "
        "advisors in connection with the licence process.",
        s["body"],
    ))
    e.append(Paragraph(
        "<b>Resolution 4 — Capital.</b> The Board notes the capital plan set out in the Business "
        "Plan and authorises management to complete equity subscription formalities so that "
        "minimum regulatory capital is fully paid up prior to commencement of lending.",
        s["body"],
    ))
    e.append(Paragraph(
        "<b>Resolution 5 — Certification.</b> The Company Secretary be authorised to certify "
        "extracts of these resolutions as true copies for delivery to CBK and third parties.",
        s["body"],
    ))
    e.append(Spacer(1, 8))
    e.append(Paragraph(
        "Certified as a true extract of the resolutions of the Board.",
        s["body"],
    ))
    e.append(Spacer(1, 14))
    e.append(Paragraph("________________________________________", s["sign"]))
    e.append(Paragraph("<b>Chairperson of the Board</b>", s["sign"]))
    e.append(Paragraph("Name: ______________________ &nbsp;&nbsp; Date: ____________", s["sign"]))
    e.append(Spacer(1, 12))
    e.append(Paragraph("________________________________________", s["sign"]))
    e.append(Paragraph("<b>Company Secretary</b>", s["sign"]))
    e.append(Paragraph("Name: ______________________ &nbsp;&nbsp; Date: ____________", s["sign"]))
    e.append(Spacer(1, 10))
    e.append(Paragraph("Company seal (if affixed): ______________________", s["sign"]))
    e.append(Spacer(1, 12))
    e.append(footer_note(s, "Document B — Board Resolution Extract"))
    e.append(PageBreak())
    return e


def doc_c_cover(s):
    e = []
    e += header_block(s)
    e.append(Paragraph(f"Our Ref: ZENI/CBK/APP/{datetime.now().year}/001", s["ref"]))
    e.append(Paragraph(f"Your Ref: [TO BE ADVISED]", s["ref"]))
    e.append(Paragraph(f"Date: {TODAY}", s["ref"]))
    e.append(Spacer(1, 8))
    e.append(Paragraph(
        "<b>The Director, Bank Supervision /</b><br/>"
        "<b>Officer-in-Charge, Digital Credit Providers</b><br/>"
        "Central Bank of Kenya<br/>"
        "Haile Selassie Avenue<br/>"
        "P.O. Box 60000 — 00200<br/>"
        "Nairobi, Kenya",
        s["body_l"],
    ))
    e.append(Spacer(1, 6))
    e.append(Paragraph("Dear Sir / Madam,", s["body_l"]))
    e.append(Paragraph(
        "RE: TRANSMITTAL OF BUSINESS PLAN AND LETTER(S) OF NO OBJECTION — "
        "ZENI LIMITED (PROPOSED DIGITAL CREDIT PROVIDER)",
        s["title"],
    ))
    e.append(Paragraph(
        "We write on behalf of <b>ZENI Limited</b> (the “Company”), [a private limited company "
        "incorporated in Kenya under company number ●●● / a company in formation], which intends "
        "to apply for authorisation to conduct digital credit business under the supervisory "
        "oversight of the Central Bank of Kenya.",
        s["body"],
    ))
    e.append(Paragraph(
        "In support of pre-application engagement and/or as part of the formal application pack "
        "(as appropriate to the stage of engagement), please find enclosed / attached:",
        s["body"],
    ))
    for b in [
        "Business Plan of ZENI Limited (Version 1.0) marked confidential for regulatory review;",
        "Shareholder / Sponsor Letter(s) of No Objection executed by [NAME(S)];",
        "Certified Board Resolution extract authorising the application;",
        "Such other schedules as listed in the application checklist (policies to follow or enclosed).",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph(
        "The Company affirms its commitment to operate only within the perimeter of activities "
        "authorised by CBK, to uphold consumer protection, data protection, AML/CFT and fair "
        "collections standards, and to engage transparently with the Bank Supervision team.",
        s["body"],
    ))
    e.append(Paragraph(
        "We should be grateful for acknowledgment of receipt and guidance on any additional "
        "information required at this stage. We remain available for a courtesy meeting at the "
        "Bank’s convenience.",
        s["body"],
    ))
    e.append(Paragraph(
        "All correspondence on this matter may be directed to:",
        s["body"],
    ))
    e.append(Paragraph(
        "<b>Contact person:</b> [FULL NAME], [CEO / Company Secretary]<br/>"
        "<b>Email:</b> [email@zeni.co.ke]<br/>"
        "<b>Telephone:</b> +254 [●●● ●●● ●●●]<br/>"
        "<b>Physical address:</b> [Nairobi office address]",
        s["body_l"],
    ))
    e.append(Spacer(1, 6))
    e.append(Paragraph("Yours faithfully,", s["sign"]))
    e.append(Paragraph("<b>FOR AND ON BEHALF OF ZENI LIMITED</b>", s["sign"]))
    e.append(Spacer(1, 16))
    e.append(Paragraph("________________________________________", s["sign"]))
    e.append(Paragraph("<b>[Name]</b>", s["sign"]))
    e.append(Paragraph("[Director / Chief Executive Officer]", s["sign"]))
    e.append(Paragraph("Date: ______________________", s["sign"]))
    e.append(Spacer(1, 10))
    e.append(Paragraph("<b>Enclosures:</b> as listed above", s["sign"]))
    e.append(Spacer(1, 8))
    e.append(Paragraph(
        "Cc: Company file; external legal counsel; Board Chairperson",
        s["small"],
    ))
    e.append(Spacer(1, 10))
    e.append(footer_note(s, "Document C — CBK Cover Transmittal Letter"))
    e.append(PageBreak())
    return e


def doc_d_checklist(s):
    e = []
    e += header_block(s, "Document D — Completion Checklist")
    e.append(Paragraph("Signing & Filing Guidance", s["title"]))
    e.append(Paragraph("1. Before you sign Document A (LONO)", s["h2"]))
    for b in [
        "Replace every [SQUARE BRACKET] placeholder with accurate legal names and percentages.",
        "Confirm the signatory has authority (board minutes, PoA, or is the individual shareholder).",
        "Align UBO / shareholding disclosures with CR12 / incorporation documents.",
        "Have Kenya counsel review — especially if the Sponsor is foreign or a regulated entity.",
        "Print on Sponsor letterhead if the Sponsor is a company; attach certificate of incorporation.",
        "Consider notarisation / apostille if CBK or counsel so advises for foreign Sponsors.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("2. Who should issue a LONO?", s["h2"]))
    for b in [
        "Each significant individual or corporate shareholder (thresholds per counsel / CBK expectation).",
        "Any parent company if ZENI is a subsidiary.",
        "Any related Kenyan licensed institution, if group structures create affiliation (to confirm no conflict).",
        "Technology / brand licensors only if using third-party IP central to the licence case.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("3. Filing with CBK", s["h2"]))
    for b in [
        "Submit originals or certified true copies as directed in the prevailing application guidance.",
        "Keep a complete duplicate pack on the Company Secretary’s file.",
        "Update LONO if shareholding changes before authorisation is granted.",
        "Never back-date signatures.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("4. Related ZENI pack", s["h2"]))
    e.append(Paragraph(
        "This LONO pack is designed to travel with <b>ZENI_CBK_Business_Plan.pdf</b>. Together they "
        "form a presentation-ready narrative and consent layer; the formal CBK application forms, "
        "capital proof, police clearances, and policy manuals remain separate mandatory files.",
        s["body"],
    ))
    e.append(Spacer(1, 8))
    rows = [
        ["Item", "Owner", "Status"],
        ["Complete placeholders", "Sponsor + Counsel", "[ ]"],
        ["Board resolution passed", "Board / Secretary", "[ ]"],
        ["LONO signed & stamped", "Sponsor", "[ ]"],
        ["Witness / notary (if required)", "Counsel", "[ ]"],
        ["Cover letter on ZENI letterhead", "CEO / Secretary", "[ ]"],
        ["Business Plan enclosed", "Management", "[ ]"],
        ["Duplicate file retained", "Company Secretary", "[ ]"],
    ]
    data = [[Paragraph(f"<b>{c}</b>" if i == 0 else c, s["body_l"]) for c in r]
            for i, r in enumerate(rows)]
    t = Table(data, colWidths=[70 * mm, 55 * mm, 45 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("TEXTCOLOR", (0, 0), (-1, 0), white),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    e.append(t)
    e.append(Spacer(1, 12))
    e.append(HRFlowable(width="100%", thickness=1, color=GREEN))
    e.append(Spacer(1, 8))
    e.append(Paragraph(
        "Disclaimer. These templates are supplied for business-planning and discussion purposes. "
        "They are not legal advice and must be customised by Kenya-qualified advocates before "
        "execution or filing with the Central Bank of Kenya. Regulatory requirements change; "
        "always verify the latest CBK forms and guidance notes.",
        s["small"],
    ))
    e.append(Paragraph("— End of Letter of No Objection Pack —", s["title"]))
    return e


def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title="ZENI Limited — Letter of No Objection Pack (CBK)",
        author="ZENI Limited",
        subject="Letter of No Objection and related CBK instruments",
    )
    s = S()
    story = []
    story += page_cover(s)
    story += doc_a_lono(s)
    story += doc_b_board(s)
    story += doc_c_cover(s)
    story += doc_d_checklist(s)
    doc.build(story)
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    build()
