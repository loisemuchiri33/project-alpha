#!/usr/bin/env python3
"""Generate ZENI Digital Credit Provider Business Plan PDF for CBK presentation."""

from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm, cm
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, KeepTogether, ListFlowable, ListItem, HRFlowable,
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from datetime import datetime

OUT = Path("/home/user/zeni/docs/ZENI_CBK_Business_Plan.pdf")
GREEN = HexColor("#0B6E4F")
GREEN_DARK = HexColor("#085540")
GREEN_SOFT = HexColor("#E6F4EF")
GOLD = HexColor("#C4A35A")
GRAY = HexColor("#4A5568")
LIGHT = HexColor("#F7FAFC")
LINE = HexColor("#CBD5E0")
MUTED = HexColor("#718096")


def styles():
    base = getSampleStyleSheet()
    s = {}
    s["cover_title"] = ParagraphStyle(
        "cover_title", parent=base["Title"],
        fontName="Helvetica-Bold", fontSize=32, textColor=white,
        alignment=TA_CENTER, spaceAfter=8, leading=38,
    )
    s["cover_sub"] = ParagraphStyle(
        "cover_sub", parent=base["Normal"],
        fontName="Helvetica", fontSize=14, textColor=HexColor("#D7F5E9"),
        alignment=TA_CENTER, spaceAfter=6, leading=20,
    )
    s["cover_meta"] = ParagraphStyle(
        "cover_meta", parent=base["Normal"],
        fontName="Helvetica", fontSize=11, textColor=HexColor("#B8E0D0"),
        alignment=TA_CENTER, leading=16,
    )
    s["h1"] = ParagraphStyle(
        "h1", parent=base["Heading1"],
        fontName="Helvetica-Bold", fontSize=16, textColor=GREEN_DARK,
        spaceBefore=16, spaceAfter=10, leading=20,
        borderPadding=3,
    )
    s["h2"] = ParagraphStyle(
        "h2", parent=base["Heading2"],
        fontName="Helvetica-Bold", fontSize=12.5, textColor=GREEN,
        spaceBefore=12, spaceAfter=6, leading=16,
    )
    s["h3"] = ParagraphStyle(
        "h3", parent=base["Heading3"],
        fontName="Helvetica-Bold", fontSize=11, textColor=HexColor("#1A365D"),
        spaceBefore=8, spaceAfter=4, leading=14,
    )
    s["body"] = ParagraphStyle(
        "body", parent=base["Normal"],
        fontName="Helvetica", fontSize=10, textColor=HexColor("#1A202C"),
        alignment=TA_JUSTIFY, leading=14, spaceAfter=6,
    )
    s["bullet"] = ParagraphStyle(
        "bullet", parent=base["Normal"],
        fontName="Helvetica", fontSize=10, textColor=HexColor("#1A202C"),
        leftIndent=12, leading=13.5, spaceAfter=3,
    )
    s["toc"] = ParagraphStyle(
        "toc", parent=base["Normal"],
        fontName="Helvetica", fontSize=11, textColor=HexColor("#2D3748"),
        leading=18, spaceAfter=4,
    )
    s["footer"] = ParagraphStyle(
        "footer", parent=base["Normal"],
        fontName="Helvetica", fontSize=8, textColor=MUTED,
        alignment=TA_CENTER,
    )
    s["cell"] = ParagraphStyle(
        "cell", parent=base["Normal"],
        fontName="Helvetica", fontSize=8.5, textColor=HexColor("#1A202C"),
        leading=11,
    )
    s["cell_h"] = ParagraphStyle(
        "cell_h", parent=base["Normal"],
        fontName="Helvetica-Bold", fontSize=8.5, textColor=white,
        leading=11,
    )
    s["disclaimer"] = ParagraphStyle(
        "disclaimer", parent=base["Normal"],
        fontName="Helvetica-Oblique", fontSize=8.5, textColor=MUTED,
        alignment=TA_JUSTIFY, leading=11, spaceBefore=8, spaceAfter=8,
    )
    s["quote"] = ParagraphStyle(
        "quote", parent=base["Normal"],
        fontName="Helvetica-Oblique", fontSize=10, textColor=GREEN_DARK,
        alignment=TA_CENTER, leading=14, leftIndent=20, rightIndent=20,
        spaceBefore=8, spaceAfter=8,
    )
    s["label"] = ParagraphStyle(
        "label", parent=base["Normal"],
        fontName="Helvetica-Bold", fontSize=9, textColor=GREEN,
        spaceBefore=4, spaceAfter=2,
    )
    return s


def add_header_footer(canvas, doc):
    canvas.saveState()
    page = doc.page
    if page > 1:
        canvas.setStrokeColor(GREEN)
        canvas.setLineWidth(1.5)
        canvas.line(18 * mm, A4[1] - 12 * mm, A4[0] - 18 * mm, A4[1] - 12 * mm)
        canvas.setFont("Helvetica-Bold", 8)
        canvas.setFillColor(GREEN)
        canvas.drawString(18 * mm, A4[1] - 10 * mm, "ZENI LIMITED")
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(MUTED)
        canvas.drawRightString(A4[0] - 18 * mm, A4[1] - 10 * mm,
                               "Business Plan — CBK Licensing Submission Pack")
        canvas.setStrokeColor(LINE)
        canvas.setLineWidth(0.5)
        canvas.line(18 * mm, 14 * mm, A4[0] - 18 * mm, 14 * mm)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(MUTED)
        canvas.drawString(18 * mm, 9 * mm, "Confidential — For Regulatory Review")
        canvas.drawRightString(A4[0] - 18 * mm, 9 * mm, f"Page {page}")
    canvas.restoreState()


def cover_page(s):
    elems = []
    # Spacer for top band (drawn via table full-width block)
    data = [[Paragraph("ZENI", s["cover_title"])],
            [Paragraph("Smart Loans. Secure Future.", s["cover_sub"])],
            [Spacer(1, 8)],
            [Paragraph("BUSINESS PLAN", s["cover_title"])],
            [Paragraph(
                "Application Support Document for Authorisation as a<br/>Digital Credit Provider in Kenya",
                s["cover_sub"])],
            [Spacer(1, 16)],
            [Paragraph(
                "Prepared for submission in connection with licensing and oversight<br/>"
                "by the Central Bank of Kenya (CBK)",
                s["cover_meta"])],
            [Spacer(1, 24)],
            [Paragraph(
                f"Version 1.0 &nbsp;|&nbsp; {datetime.now().strftime('%B %Y')}<br/>"
                "Classification: Confidential — Regulatory",
                s["cover_meta"])],
            ]
    t = Table(data, colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), GREEN_DARK),
        ("ALIGN", (0, 0), (-1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 20),
        ("RIGHTPADDING", (0, 0), (-1, -1), 20),
        ("TOPPADDING", (0, 0), (-1, 0), 40),
        ("BOTTOMPADDING", (0, -1), (-1, -1), 40),
    ]))
    elems.append(Spacer(1, 25 * mm))
    elems.append(t)
    elems.append(Spacer(1, 18 * mm))
    meta = [
        [Paragraph("<b>Applicant</b>", s["cell"]),
         Paragraph("ZENI Limited (proposed / in formation)", s["cell"])],
        [Paragraph("<b>Business activity</b>", s["cell"]),
         Paragraph("Digital credit (consumer micro-lending) via mobile application", s["cell"])],
        [Paragraph("<b>Primary market</b>", s["cell"]),
         Paragraph("Republic of Kenya", s["cell"])],
        [Paragraph("<b>Currency</b>", s["cell"]),
         Paragraph("Kenya Shilling (KES)", s["cell"])],
        [Paragraph("<b>Document purpose</b>", s["cell"]),
         Paragraph(
             "Strategic, operational, financial and compliance framework for CBK engagement",
             s["cell"])],
    ]
    mt = Table(meta, colWidths=[45 * mm, 125 * mm])
    mt.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), LIGHT),
        ("BOX", (0, 0), (-1, -1), 0.5, LINE),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
        ("LEFTPADDING", (0, 0), (-1, -1), 8),
        ("RIGHTPADDING", (0, 0), (-1, -1), 8),
    ]))
    elems.append(mt)
    elems.append(Spacer(1, 12 * mm))
    elems.append(Paragraph(
        "This document is a business and compliance planning instrument. It does not constitute "
        "legal advice. Final licence application forms, fit-and-proper declarations, capital "
        "evidence and court-certified documents will be filed under the applicable CBK Digital "
        "Credit Provider regulatory instruments and guidance notes in force at the time of filing.",
        s["disclaimer"],
    ))
    elems.append(PageBreak())
    return elems


def toc(s):
    items = [
        "1. Executive Summary",
        "2. Regulatory Positioning and Licensing Intent",
        "3. Company Overview and Corporate Governance",
        "4. Market Opportunity (Kenya Digital Credit)",
        "5. Products and Pricing Philosophy",
        "6. Technology Architecture and Information Security",
        "7. Credit Underwriting, Risk and Fraud Controls",
        "8. Payments, Disbursement and Collections (M-Pesa)",
        "9. Consumer Protection and Fair Treatment",
        "10. Data Protection and Privacy (Kenya DPA)",
        "11. AML/CFT and Financial Crime Compliance",
        "12. Credit Information Sharing and CRB Engagement",
        "13. Operational Resilience and Business Continuity",
        "14. Organisation, People and Outsourcing",
        "15. Financial Plan and Capital Adequacy",
        "16. Implementation Roadmap",
        "17. Risk Register and Mitigations",
        "18. Annexes and Supporting Schedules",
    ]
    elems = [Paragraph("Table of Contents", s["h1"])]
    for it in items:
        elems.append(Paragraph(it, s["toc"]))
    elems.append(Spacer(1, 8))
    elems.append(HRFlowable(width="100%", thickness=0.5, color=LINE))
    elems.append(Paragraph(
        "Primary audience: Central Bank of Kenya supervisory and licensing reviewers; secondary "
        "audience: co-investors, professional advisors and internal Board.",
        s["disclaimer"],
    ))
    elems.append(PageBreak())
    return elems


def section_exec(s):
    e = []
    e.append(Paragraph("1. Executive Summary", s["h1"]))
    e.append(Paragraph(
        "ZENI is a Kenya-focused digital credit platform designed to extend small, transparent, "
        "short-duration loans to formally and informally employed adults through a mobile-first "
        "experience. The platform combines conservative credit ladders, strong identity and fraud "
        "controls, M-Pesa rails for disbursement and repayment, and a compliance-by-design "
        "operating model aligned with Central Bank of Kenya expectations for Digital Credit Providers.",
        s["body"],
    ))
    e.append(Paragraph(
        "ZENI’s mission is to expand responsible access to working capital and consumption-smoothing "
        "credit while protecting borrowers from opaque pricing, aggressive collections and data abuse. "
        "The brand proposition — <i>Smart Loans. Secure Future.</i> — signals both product simplicity "
        "and institutional seriousness.",
        s["body"],
    ))
    e.append(Paragraph("1.1 Strategic Objectives (First 36 Months)", s["h2"]))
    for b in [
        "Secure CBK authorisation as a Digital Credit Provider (DCP) and maintain continuous supervisory readiness.",
        "Launch a production-grade mobile and API stack with end-to-end encryption, auditability and consumer disclosures.",
        "Originate solely KES-denominated, fully disclosed consumer digital credit within approved product limits.",
        "Build a repeatable governance cadence: Board risk committee, compliance officer, internal audit, complaints MI.",
        "Establish credit reference bureau integration, AML transaction monitoring, and ODPC-aligned privacy operations.",
        "Achieve operational break-even on a disciplined underwriting and cost-to-serve model (see Financial Plan).",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Paragraph("1.2 Snapshot Metrics (Indicative Planning Case)", s["h2"]))
    hdr = [Paragraph(x, s["cell_h"]) for x in
           ["Metric", "Year 1", "Year 2", "Year 3"]]
    rows = [
        ["Active borrowers (EOP)", "45,000", "140,000", "320,000"],
        ["Gross loan book (KES m)", "180", "720", "1,850"],
        ["Avg. disbursement (KES)", "8,500", "10,500", "12,000"],
        ["Portfolio at Risk >30d", "≤ 8%", "≤ 7%", "≤ 6%"],
        ["Complaints resolution (SLA)", "≤ 7 days", "≤ 5 days", "≤ 5 days"],
    ]
    data = [hdr] + [[Paragraph(c, s["cell"]) for c in r] for r in rows]
    t = Table(data, colWidths=[55 * mm, 35 * mm, 35 * mm, 35 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("BACKGROUND", (0, 1), (-1, -1), LIGHT),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
    ]))
    e.append(t)
    e.append(Paragraph(
        "Figures are management planning assumptions for capital and capacity sizing. They will be "
        "updated in the formal licence application pack with audited/opening financials and stress cases.",
        s["disclaimer"],
    ))
    e.append(Paragraph("1.3 Why ZENI Merits Supervisory Confidence", s["h2"]))
    e.append(Paragraph(
        "ZENI is engineered as a regulated financial institution from day one: segregation of duties, "
        "immutable audit logs, interest and fee pre-disclosure before contract acceptance, cool-off "
        "and hardship pathways, prohibitions on abusive collections, and technical controls "
        "(Argon2id credentials, AES-256-GCM field encryption, JWT session hygiene, rate limits, fraud "
        "scoring). The firm seeks partnership with the CBK’s consumer-protection objectives — not "
        "regulatory arbitrage.",
        s["body"],
    ))
    return e


def section_reg(s):
    e = []
    e.append(Paragraph("2. Regulatory Positioning and Licensing Intent", s["h1"]))
    e.append(Paragraph(
        "ZENI intends to operate only after obtaining all required authorisations for digital "
        "credit business in Kenya. The company will structure its application consistent with the "
        "Central Bank of Kenya’s Digital Credit Providers regulatory framework (including the CBK "
        "(Digital Credit Providers) Regulations, accompanying guidance, circulars and prudential "
        "expectations as updated from time to time).",
        s["body"],
    ))
    e.append(Paragraph("2.1 Regulatory Perimeter", s["h2"]))
    for b in [
        "Activity: granting of digital credit to natural persons via electronic delivery channels.",
        "Non-activity (phase 1): deposit-taking, issuance of e-money as a primary business, securities dealing, insurance underwriting.",
        "Payment execution: through licensed PSPs / mobile money (Safaricom M-Pesa Daraja) under contractual arrangements; ZENI is not seeking to become a payments utility in phase 1.",
        "Geographic scope: Kenya only at authorisation; no cross-border lending without prior CBK engagement.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("2.2 Licence Application Building Blocks", s["h2"]))
    e.append(Paragraph(
        "The formal application pack (to be submitted under CBK-prescribed forms) will include, "
        "inter alia: constitutional documents; ownership and beneficial ownership maps; fit-and-proper "
        "questionnaires for significant owners, directors and key officers; business plan (this document "
        "and updates); financial projections and capital evidence; ICT and cybersecurity policies; credit "
        "and pricing policy; consumer protection policy; complaints handling policy; data protection "
        "impact assessments; AML/CFT programme; draft customer agreements and disclosure templates; "
        "outsourcing register; and business continuity / disaster recovery plans.",
        s["body"],
    ))
    e.append(Paragraph("2.3 Supervisory Engagement Style", s["h2"]))
    e.append(Paragraph(
        "ZENI commits to proactive disclosure of material incidents (ICT, fraud, consumer harm), "
        "timely responses to CBK information requests, and peace-time participation in industry "
        "dialogues on responsible digital lending. Material product or pricing changes will follow "
        "internal governance and, where required, prior notification to or approval by the CBK.",
        s["body"],
    ))
    return e


def section_company(s):
    e = []
    e.append(Paragraph("3. Company Overview and Corporate Governance", s["h1"]))
    e.append(Paragraph("3.1 Legal Form and Seat", s["h2"]))
    e.append(Paragraph(
        "ZENI Limited will be incorporated under the Companies Act of Kenya as a private company "
        "limited by shares, with registered office in Nairobi. Shareholding will be transparent; any "
        "foreign ownership will be disclosed with source-of-funds evidence and banks of account.",
        s["body"],
    ))
    e.append(Paragraph("3.2 Governance Architecture", s["h2"]))
    e.append(Paragraph(
        "The Board of Directors retains ultimate accountability for strategy, risk appetite, capital, "
        "conduct and compliance culture. At minimum, Board committees will cover:",
        s["body"],
    ))
    for b in [
        "Board Risk & Credit Committee — risk appetite, PAR, model performance, provisioning.",
        "Board Audit Committee — internal control, external audit, policy attestation.",
        "Board Nominations & Remuneration — fit-and-proper, succession, incentive alignment (no volume-only sales incentives).",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("3.3 Senior Management (Control Functions)", s["h2"]))
    rows = [
        ["Role", "Mandate (summary)"],
        ["Chief Executive Officer", "Strategy execution; regulatory relationship owner with Board oversight"],
        ["Chief Risk Officer", "Independent risk; credit policy; portfolio & model risk; 2nd line"],
        ["Chief Finance Officer", "Capital, liquidity of lending book funding, financial reporting"],
        ["Chief Technology Officer", "ICT resilience, cybersecurity, change management"],
        ["Chief Compliance Officer / MLRO", "Conduct, DCP obligations, AML/CFT, SAR filing"],
        ["Head of Customer Experience", "Complaints, collections quality, fair treatment MI"],
        ["Internal Audit (in-house or co-sourced)", "Risk-based assurance; reports to Audit Committee"],
    ]
    data = [[Paragraph(c, s["cell_h"] if i == 0 else s["cell"]) for c in r]
            for i, r in enumerate(rows)]
    t = Table(data, colWidths=[55 * mm, 115 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    e.append(t)
    e.append(Paragraph("3.4 Three Lines of Defence", s["h2"]))
    e.append(Paragraph(
        "First line (business and product) owns risk. Second line (risk & compliance) sets frameworks "
        "and challenges. Third line (internal audit) provides independent assurance. No single "
        "individual may originate, approve and disburse material credit exceptions without dual control.",
        s["body"],
    ))
    return e


def section_market(s):
    e = []
    e.append(Paragraph("4. Market Opportunity (Kenya Digital Credit)", s["h1"]))
    e.append(Paragraph(
        "Kenya remains a continental leader in mobile money penetration and smartphone-led financial "
        "services. Demand for short-tenor liquidity among MSME traders, gig workers, salaried staff "
        "facing cash-flow gaps, and households managing lumpy expenses remains structurally high. "
        "At the same time, the market has been shaped by supervisory reforms aimed at curbing "
        "predatory practices that previously damaged public trust.",
        s["body"],
    ))
    e.append(Paragraph("4.1 Customer Segments (Phase 1)", s["h2"]))
    for b in [
        "Employed and self-employed adults aged 21+ with verifiable mobile money footprint.",
        "Micro-traders needing inventory floats (KES 5,000–35,000 ladder).",
        "Repeat borrowers graduating through positive repayment behaviour to higher limits.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("4.2 Competitive Differentiation", s["h2"]))
    for b in [
        "Transparent APR / total cost of credit shown before acceptance — no buried fees.",
        "Conservative laddering: start small (from KES 5,000) and grow with performance.",
        "Security-first stack (see Section 6) as a brand asset, not a backend detail.",
        "Human + digital complaints desk; collections that comply with dignity and law.",
        "Aligned with CBK conduct theme: affordability and suitability over pure conversion.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("4.3 Market Risks", s["h2"]))
    e.append(Paragraph(
        "Macro shocks, mobile money tariff changes, intense competition, fraud rings, and "
        "reputational contagion from industry misconduct are material. ZENI’s mitigants are "
        "capital buffers, diversified acquisition (not only paid ads), strong fraud rules, "
        "and board-level conduct MI.",
        s["body"],
    ))
    return e


def section_product(s):
    e = []
    e.append(Paragraph("5. Products and Pricing Philosophy", s["h1"]))
    e.append(Paragraph("5.1 Core Product — ZENI Flex Loan", s["h2"]))
    e.append(Paragraph(
        "A fully digital, unsecured consumer instalment / bullet micro-loan, disbursed in KES to the "
        "borrower’s registered M-Pesa number, with contractual due date and in-app repayment via STK push.",
        s["body"],
    ))
    hdr = [Paragraph(x, s["cell_h"]) for x in ["Parameter", "Phase-1 Policy"]]
    rows = [
        ["Currency", "KES only"],
        ["Ticket size ladder", "5,000 → 10,000 → 15,000 → 20,000 → 25,000 → 30,000 → 35,000"],
        ["Tenor", "7 to 60 days at launch (extendable by Board & CBK engagement)"],
        ["Interest philosophy", "Risk-based bands; low / medium / high with clear disclosure"],
        ["Indicative rates (planning)", "Approx. 12%–20% on a normalised annualised basis depending on risk band and tenor — exact tariffs locked in Pricing Policy Schedule"],
        ["Fees", "One-time facility fee where used; fully disclosed in Total Cost of Credit"],
        ["Late fees", "Capped; progressive but not usurious; hardship pathway available"],
        ["Collateral", "None (clean digital unsecured)"],
        ["Restructuring", "Documented hardship and extension rules; not infinite roll-overs that mask distress"],
    ]
    data = [hdr] + [[Paragraph(c, s["cell"]) for c in r] for r in rows]
    t = Table(data, colWidths=[45 * mm, 125 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    e.append(t)
    e.append(Paragraph("5.2 Pricing Principles (Conduct)", s["h2"]))
    for b in [
        "All costs expressed as Total Amount Payable and Total Cost of Credit before e-acceptance.",
        "No surprise charges post-disbursement other than contractual, pre-disclosed late charges.",
        "No fee for mandatory loan statements within a fair use policy.",
        "Marketing claims will be substantiated and not hide risk of over-indebtedness.",
        "Incentive schemes for staff and agents will not reward reckless origination.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("5.3 Product Governance", s["h2"]))
    e.append(Paragraph(
        "New products or material pricing changes require Credit/Risk Committee review, Compliance "
        "sign-off on disclosures, technology change control, and Board awareness. Where supervisory "
        "rules require notification or approval, ZENI will comply before go-live.",
        s["body"],
    ))
    return e


def section_tech(s):
    e = []
    e.append(Paragraph("6. Technology Architecture and Information Security", s["h1"]))
    e.append(Paragraph(
        "ZENI’s production architecture (mobile app, API, data stores, workers) is designed for "
        "confidentiality, integrity, availability and auditability appropriate to a regulated lender.",
        s["body"],
    ))
    e.append(Paragraph("6.1 Logical Architecture", s["h2"]))
    for b in [
        "Client: Flutter mobile applications (Android/iOS) with secure token storage.",
        "Edge: TLS termination, WAF/rate limits, security headers, reverse proxy (Nginx).",
        "Application: Go (Gin) API services; asynchronous workers for loan processing and late-fee jobs.",
        "Data: PostgreSQL (system of record), Redis (OTP, rate, short-lived fraud counters), object storage for KYC artefacts (encrypted, private buckets).",
        "Integrations: M-Pesa Daraja (STK, callbacks), SMS OTP gateway, CRB interfaces, optional analytics with privacy controls.",
        "Observability: structured logs, metrics (Prometheus), tracing-ready design, immutable audit events for privileged actions.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("6.2 Security Control Highlights", s["h2"]))
    for b in [
        "Password hashing: Argon2id (memory-hard).",
        "Field-level encryption: AES-256-GCM for sensitive payloads at rest.",
        "Session security: short-lived JWT access tokens + refresh rotation; server-side revocation pathway.",
        "OTP: single-use, TTL-bound, rate-limited.",
        "Transport: TLS 1.2+ (target TLS 1.3); HSTS at edge.",
        "Application: input validation, RBAC for admin, least privilege DB roles, secrets via environment / vault — never in source control.",
        "Fraud: multi-rule scoring (velocity, device, amount anomaly, geo/time anomalies) with allow / review / reject actions.",
        "SDLC: code review, dependency scanning, CI tests, controlled production change windows.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("6.3 Cybersecurity Governance", s["h2"]))
    e.append(Paragraph(
        "A written Information Security Policy, Incident Response Plan, and annual independent "
        "penetration test (prior to scale and then periodic) underpin the control environment. "
        "Material cyber incidents meeting regulatory thresholds will be reported to CBK and, where "
        "applicable, to the Office of the Data Protection Commissioner and affected customers.",
        s["body"],
    ))
    e.append(Paragraph("6.4 Data Residency and Hosting", s["h2"]))
    e.append(Paragraph(
        "Production customer data will be hosted in regulated-cloud or tier-rated Kenyan/regional "
        "facilities meeting resilience and legal access standards. Cross-border processing, if any, "
        "will use appropriate transfer safeguards under the Kenya Data Protection Act.",
        s["body"],
    ))
    return e


def section_credit(s):
    e = []
    e.append(Paragraph("7. Credit Underwriting, Risk and Fraud Controls", s["h1"]))
    e.append(Paragraph("7.1 Credit Philosophy", s["h2"]))
    e.append(Paragraph(
        "Lend amounts customers can reasonably repay; enlarge limits only on demonstrated behaviour. "
        "Reject or refer high-fraud and unaffordable cases. Avoid debt spiral products disguised as convenience.",
        s["body"],
    ))
    e.append(Paragraph("7.2 Underwriting Inputs (Phased)", s["h2"]))
    for b in [
        "Identity & SIM/phone hygiene, KYC tier, device fingerprint signals.",
        "Repayment history on ZENI; velocity of applications.",
        "CRB footprint (negative data, active NPL signals) as coverage increases.",
        "Self-declared income and affordability checks proportionate to ticket size.",
        "Fraud engine risk score and manual review queues for grey cases.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("7.3 Limit Ladder & Interest Bands", s["h2"]))
    e.append(Paragraph(
        "Starting limits favour smaller tickets. Progression to higher ladder steps requires on-time "
        "closures and stable fraud posture. Interest bands (low / medium / high risk) are "
        "policy-controlled and versioned.",
        s["body"],
    ))
    e.append(Paragraph("7.4 Portfolio Monitoring", s["h2"]))
    for b in [
        "Daily PAR buckets (1+, 7+, 30+, 90+).",
        "Vintage curves and collection effectiveness.",
        "Concentration by channel, device cluster, geography.",
        "Model drift monitoring when scorecards are introduced.",
        "Loss provisioning methodology documented and Board-approved.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("7.5 Fraud", s["h2"]))
    e.append(Paragraph(
        "ZENI’s multi-rule detector assigns weighted scores and actions (allow / review / reject). "
        "Confirmed fraud is charged-off per policy, fed back into rules, and where criminal, "
        "referred appropriately without victimising legitimate customers via blunt blacklists.",
        s["body"],
    ))
    return e


def section_payments(s):
    e = []
    e.append(Paragraph("8. Payments, Disbursement and Collections (M-Pesa)", s["h1"]))
    e.append(Paragraph(
        "Customer money movement is executed via Safaricom M-Pesa APIs (Daraja) under commercial "
        "contracts and Safaricom’s onboarding due diligence. Disbursements credit the borrower’s "
        "registered MSISDN; repayments use STK Push with server-side callback reconciliation.",
        s["body"],
    ))
    e.append(Paragraph("8.1 Controls", s["h2"]))
    for b in [
        "Reconciliation of every callback to loan ledger entries with unique transaction references.",
        "Dual control on shortcode configuration and production credential rotation.",
        "Idempotent payment posting to prevent double-application.",
        "Exceptions queue for unmatched callbacks with aging SLA.",
        "No cash collections by field agents in phase 1 without additional licensing/procedural controls.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("8.2 Collections Conduct", s["h2"]))
    e.append(Paragraph(
        "Collections scripts prohibit threats, public shaming, contact with unrelated third parties "
        "beyond lawful norms, and disclosure of debt on social media. Contact frequency windows "
        "respect customer dignity. Digital reminders precede human outreach. Customers may receive "
        "hardship assessment when they self-identify genuine shocks.",
        s["body"],
    ))
    return e


def section_consumer(s):
    e = []
    e.append(Paragraph("9. Consumer Protection and Fair Treatment", s["h1"]))
    e.append(Paragraph(
        "Consumer protection is a first-order design constraint, not a marketing annex. ZENI "
        "adopts the following commitments.",
        s["body"],
    ))
    e.append(Paragraph("9.1 Pre-Contract Clarity", s["h2"]))
    for b in [
        "Key Fact Statement / pre-contract summary: amount, tenor, interest, fees, total payable, due date, consequences of default — in plain English and Kiswahili where feasible.",
        "Clickwrap acceptance with immutable versioned T&Cs and timestamped audit.",
        "Ability to abandon application with no charge before disbursement.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("9.2 During Contract", s["h2"]))
    for b in [
        "In-app balance, schedule and payment history.",
        "Fair repayment channels; prompt receipting.",
        "Prohibition of unsolicited top-ups that conceal distress.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("9.3 Complaints Handling", s["h2"]))
    e.append(Paragraph(
        "Multi-channel intake (in-app, email, phone). Unique ticket IDs. Target acknowledgment "
        "within 24 working hours and resolution within 7 calendar days for standard cases "
        "(complex cases escalated with interim updates). Root-cause themes reported to Board Risk "
        "quarterly. Unresolved disputes may be escalated to existing statutory ombuds / CBK consumer "
        "protection channels as applicable.",
        s["body"],
    ))
    e.append(Paragraph("9.4 Marketing and Sales Conduct", s["h2"]))
    e.append(Paragraph(
        "No dark patterns that force continuous borrowing. No harvesting of phone contacts for "
        "shaming. Consent for marketing is separate from credit contracts.",
        s["body"],
    ))
    return e


def section_data(s):
    e = []
    e.append(Paragraph("10. Data Protection and Privacy (Kenya DPA)", s["h1"]))
    e.append(Paragraph(
        "ZENI will register as a data controller/processor with the Office of the Data Protection "
        "Commissioner as required, maintain a Record of Processing Activities, and implement "
        "Data Protection Impact Assessments for high-risk processing (credit scoring, biometrics if used).",
        s["body"],
    ))
    for b in [
        "Lawful basis mapped per processing purpose (contract, legal obligation, legitimate interests, consent where required).",
        "Purpose limitation and data minimisation — especially for device and location signals used in fraud.",
        "Retention schedules; secure deletion / anonymisation after statutory and credit-risk need.",
        "Data subject rights procedures (access, correction, deletion where applicable).",
        "Processor contracts with standard contractual clauses; security questionnaires for vendors.",
        "Breach notification playbooks consistent with ODPC timelines.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    return e


def section_aml(s):
    e = []
    e.append(Paragraph("11. AML/CFT and Financial Crime Compliance", s["h1"]))
    e.append(Paragraph(
        "Although digital micro-loans are lower ticket, ZENI recognises mule-account and proceeds-of-"
        "crime risks. A Board-approved AML/CFT Policy will implement risk-based KYC, ongoing "
        "monitoring, sanctions screening proportionate to non-deposit lender profile, STR/SAR "
        "escalation via the MLRO, staff training, and independent audit of the AML programme.",
        s["body"],
    ))
    for b in [
        "Customer due diligence at onboarding (identity document + mobile number ownership checks).",
        "Enhanced due diligence for higher risk flags (name match, unusual velocity, third-party repayments).",
        "Record-keeping aligned to Proceeds of Crime and Anti-Money Laundering Act requirements.",
        "No deliberate anonymity products.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    return e


def section_crb(s):
    e = []
    e.append(Paragraph("12. Credit Information Sharing and CRB Engagement", s["h1"]))
    e.append(Paragraph(
        "ZENI will participate in licensed credit reference bureau ecosystems in accordance with "
        "Kenyan credit information sharing rules. Accurate, timely reporting of non-performance "
        "protects the wider financial system; equally, ZENI will ensure customers are notified of "
        "reporting practices in plain language and that data submitted is accurate and dispute-ready.",
        s["body"],
    ))
    for b in [
        "Pre-disbursement CRB checks once contractual/technical onboarding completes.",
        "Periodic submission of performing and non-performing accounts per bureau schemas.",
        "Customer dispute portal for CRB data challenges with investigation SLA.",
        "Strict access controls over bureau credentials and query logs.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    return e


def section_ops(s):
    e = []
    e.append(Paragraph("13. Operational Resilience and Business Continuity", s["h1"]))
    e.append(Paragraph(
        "ZENI targets high availability for customer-critical paths (login, loan status, repayment). "
        "RTO/RPO objectives will be Board-approved. Annual DR exercises, backup encryption, "
        "multi-AZ deployment for core data stores, and runbooks for M-Pesa or DNS outages are mandatory "
        "before mass marketing.",
        s["body"],
    ))
    for b in [
        "Health probes, autoscaling where appropriate, chaos-light game days quarterly.",
        "Vendor lock-in watch: multi-region backup of critical configurations.",
        "Crisis communication plan for customers and supervisors during extended outages.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    return e


def section_org(s):
    e = []
    e.append(Paragraph("14. Organisation, People and Outsourcing", s["h1"]))
    e.append(Paragraph(
        "Headcount ramps with book size. Critical control roles (Risk, Compliance/MLRO, Finance, "
        "CTO) are occupied before aggressive customer acquisition. Outsourcing (cloud, KYC vendor, "
        "contact centre) is governed by a Board outsourcing policy: due diligence, SLAs, audit rights, "
        "exit plans, and data protection schedules. Material outsourcing will be disclosed to CBK as required.",
        s["body"],
    ))
    return e


def section_finance(s):
    e = []
    e.append(Paragraph("15. Financial Plan and Capital Adequacy", s["h1"]))
    e.append(Paragraph(
        "Lending capacity is constrained first by capital and second by funding. ZENI will hold "
        "capital at or above CBK-prescribed minimums for DCPs and may voluntarily hold buffers "
        "above the floor during ramp-up. Funding sources may include founder equity, venture / PE "
        "equity, and senior lending facilities from local banks or DFIs — none of which dilute "
        "consumer-protection obligations.",
        s["body"],
    ))
    e.append(Paragraph("15.1 Illustrative P&L Skeleton (KES millions)", s["h2"]))
    hdr = [Paragraph(x, s["cell_h"]) for x in
           ["Item", "Year 1", "Year 2", "Year 3"]]
    rows = [
        ["Interest & fee income", "54", "250", "720"],
        ["Interest / funding cost", "(12)", "(55)", "(160)"],
        ["Net interest / fee margin", "42", "195", "560"],
        ["Impairment charges", "(18)", "(70)", "(170)"],
        ["Operating expenses", "(48)", "(95)", "(180)"],
        ["Operating profit / (loss)", "(24)", "30", "210"],
    ]
    data = [hdr] + [[Paragraph(c, s["cell"]) for c in r] for r in rows]
    t = Table(data, colWidths=[55 * mm, 35 * mm, 35 * mm, 35 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    e.append(t)
    e.append(Paragraph(
        "Illustrative only. Final projections in the licence pack will include monthly cash flows, "
        "stress tests (PAR spikes, funding freezes), and opening balance sheet certification.",
        s["disclaimer"],
    ))
    e.append(Paragraph("15.2 Use of Proceeds (Capital Raise)", s["h2"]))
    for b in [
        "Loan book seed capital and loss-absorption buffer.",
        "ICT security, core platform hardening, and CRB integrations.",
        "Licensing, legal, audit and independent security assessments.",
        "Customer support and collections quality capacity.",
        "Liquidity reserve for operational continuity.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph("15.3 Accounting and External Assurance", s["h2"]))
    e.append(Paragraph(
        "Financial statements under IFRS as applicable; external auditor licensed in Kenya; "
        "management letter themes tracked to closure by the Audit Committee.",
        s["body"],
    ))
    return e


def section_roadmap(s):
    e = []
    e.append(Paragraph("16. Implementation Roadmap", s["h1"]))
    rows = [
        ["Phase", "Timing (indicative)", "Milestones"],
        ["0 — Corporate formation", "T0–T+2 months",
         "Incorporation, bank accounts, draft policies, key hires, advisor engagement"],
        ["1 — Licence preparation", "T+2–T+6 months",
         "Full CBK application pack, capitalisation, pen-test, consumer docs, vendor KYC"],
        ["2 — Authorisation & soft launch", "Post-approval + 3 months",
         "Limited cohort lending, end-to-end control testing, CBK reporting dry runs"],
        ["3 — Scale", "Months 4–24 post-launch",
         "Channel expansion, CRB depth, automated decisioning under model governance"],
        ["4 — Optimise", "Year 3+",
         "Portfolio analytics maturity, possible adjacent products with fresh approvals"],
    ]
    data = [[Paragraph(c, s["cell_h"] if i == 0 else s["cell"]) for c in r]
            for i, r in enumerate(rows)]
    t = Table(data, colWidths=[40 * mm, 40 * mm, 90 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
    ]))
    e.append(t)
    e.append(Paragraph(
        "No live customer origination of regulated digital credit before requisite CBK authorisation "
        "is in hand (except permitted testing under any sandbox or exemption expressly granted).",
        s["body"],
    ))
    return e


def section_risks(s):
    e = []
    e.append(Paragraph("17. Risk Register and Mitigations", s["h1"]))
    rows = [
        ["Risk", "Impact", "Mitigation"],
        ["Licence delay", "High", "Early CBK engagement; complete pack; surplus capital timeline"],
        ["Credit losses above plan", "High", "Tight ladder; early collection; cut acquisition channels"],
        ["Funding shock", "High", "Committed equity runway; diversified funders; growth brakes"],
        ["Cyber incident", "High", "Defence-in-depth; IR retainer; customer/CBK/ODPC notification"],
        ["Conduct failure / viral complaint", "High", "Scripts, QA, severance of abusive agents, public correction"],
        ["M-Pesa / telecom outage", "Medium", "Status page; queued repayments; manual exception desk"],
        ["Key person dependency", "Medium", "Deputies, documentation, Board succession map"],
        ["Model discrimination / bias", "Medium", "Fairness tests before automation; human appeal path"],
    ]
    data = [[Paragraph(c, s["cell_h"] if i == 0 else s["cell"]) for c in r]
            for i, r in enumerate(rows)]
    t = Table(data, colWidths=[45 * mm, 25 * mm, 100 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), GREEN),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [white, LIGHT]),
        ("BOX", (0, 0), (-1, -1), 0.5, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
    ]))
    e.append(t)
    return e


def section_annex(s):
    e = []
    e.append(Paragraph("18. Annexes and Supporting Schedules", s["h1"]))
    e.append(Paragraph(
        "The following schedules accompany or will accompany the formal CBK filing (as separate tabs/files):",
        s["body"],
    ))
    for b in [
        "A — Shareholding & Ultimate Beneficial Ownership chart",
        "B — Draft Customer Key Fact Statement and Agreement templates (English / Kiswahili)",
        "C — Credit Policy & Pricing Tariff Schedule",
        "D — Consumer Protection & Complaints Policy",
        "E — Information Security, Incident Response, BCP/DR",
        "F — AML/CFT Policy & MLRO mandate",
        "G — Data Protection Policy, ROPA summary, DPIA abstracts",
        "H — Organisation chart and fit-and-proper files index",
        "I — Financial model (Excel) with stress cases",
        "J — ICT architecture diagrams and pen-test executive summary",
        "K — Material outsourcing register",
        "L — Sample management information pack for Board / CBK returns",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Paragraph("Closing Statement", s["h2"]))
    e.append(Paragraph(
        "ZENI seeks to join Kenya’s formal digital credit sector as a well-governed, technology-strong, "
        "consumer-respecting lender. We welcome rigorous supervisory scrutiny and will measure success "
        "not only by loan growth but by repayment sustainability, complaint quality and public trust.",
        s["body"],
    ))
    e.append(Spacer(1, 10))
    e.append(HRFlowable(width="100%", thickness=1, color=GREEN))
    e.append(Spacer(1, 8))
    e.append(Paragraph(
        "Document control: Version 1.0 — Business Plan for CBK engagement.<br/>"
        "Owner: Board of Directors (proposed) / Chief Executive Officer.<br/>"
        "Next review: upon material change or prior to formal licence filing.",
        s["disclaimer"],
    ))
    e.append(Paragraph(
        "— End of Business Plan —",
        s["quote"],
    ))
    return e


def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=18 * mm,
        title="ZENI Limited — Business Plan for CBK Digital Credit Provider Authorisation",
        author="ZENI Limited",
        subject="Confidential regulatory business plan",
    )
    s = styles()
    story = []
    story += cover_page(s)
    story += toc(s)
    story += section_exec(s)
    story += section_reg(s)
    story += section_company(s)
    story += section_market(s)
    story += section_product(s)
    story += section_tech(s)
    story += section_credit(s)
    story += section_payments(s)
    story += section_consumer(s)
    story += section_data(s)
    story += section_aml(s)
    story += section_crb(s)
    story += section_ops(s)
    story += section_org(s)
    story += section_finance(s)
    story += section_roadmap(s)
    story += section_risks(s)
    story += section_annex(s)
    doc.build(story, onFirstPage=add_header_footer, onLaterPages=add_header_footer)
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    build()
