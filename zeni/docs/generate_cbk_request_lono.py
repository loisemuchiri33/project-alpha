#!/usr/bin/env python3
"""Improved CBK Request for Letter of No Objection — Zeni Loan Limited."""

from pathlib import Path
from datetime import datetime
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, white
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable, PageBreak,
)

OUT = Path("/home/user/zeni/docs/ZENI_CBK_Request_for_Letter_of_No_Objection.pdf")
GREEN = HexColor("#0B6E4F")
GREEN_DARK = HexColor("#085540")
LIGHT = HexColor("#F7FAFC")
LINE = HexColor("#CBD5E0")
MUTED = HexColor("#718096")
TEXT = HexColor("#1A202C")
TODAY = datetime.now().strftime("%d %B %Y")


def styles():
    b = getSampleStyleSheet()
    return {
        "brand": ParagraphStyle(
            "brand", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=16, textColor=GREEN_DARK, alignment=TA_CENTER, leading=19,
        ),
        "tag": ParagraphStyle(
            "tag", parent=b["Normal"], fontName="Helvetica",
            fontSize=9, textColor=GREEN, alignment=TA_CENTER, leading=12,
        ),
        "small_c": ParagraphStyle(
            "small_c", parent=b["Normal"], fontName="Helvetica",
            fontSize=8, textColor=MUTED, alignment=TA_CENTER, leading=11,
        ),
        "ref": ParagraphStyle(
            "ref", parent=b["Normal"], fontName="Helvetica",
            fontSize=10, textColor=TEXT, leading=14, spaceAfter=1,
        ),
        "ref_r": ParagraphStyle(
            "ref_r", parent=b["Normal"], fontName="Helvetica",
            fontSize=10, textColor=TEXT, alignment=TA_RIGHT, leading=14,
        ),
        "addr": ParagraphStyle(
            "addr", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, leading=14, spaceAfter=2,
        ),
        "re": ParagraphStyle(
            "re", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=10.5, textColor=GREEN_DARK, alignment=TA_CENTER,
            leading=14, spaceBefore=8, spaceAfter=10,
        ),
        "body": ParagraphStyle(
            "body", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, alignment=TA_JUSTIFY,
            leading=15, spaceAfter=8,
        ),
        "body_l": ParagraphStyle(
            "body_l", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, alignment=TA_LEFT,
            leading=14.5, spaceAfter=5,
        ),
        "h": ParagraphStyle(
            "h", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=10.5, textColor=GREEN_DARK, spaceBefore=6, spaceAfter=4, leading=13,
        ),
        "bullet": ParagraphStyle(
            "bullet", parent=b["Normal"], fontName="Helvetica",
            fontSize=10, textColor=TEXT, leftIndent=10, leading=13.5, spaceAfter=3,
        ),
        "sign": ParagraphStyle(
            "sign", parent=b["Normal"], fontName="Helvetica",
            fontSize=10.5, textColor=TEXT, leading=14, spaceAfter=2,
        ),
        "cell": ParagraphStyle(
            "cell", parent=b["Normal"], fontName="Helvetica",
            fontSize=9.5, textColor=TEXT, leading=12,
        ),
        "cell_b": ParagraphStyle(
            "cell_b", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=9.5, textColor=TEXT, leading=12,
        ),
        "foot": ParagraphStyle(
            "foot", parent=b["Normal"], fontName="Helvetica-Oblique",
            fontSize=7.5, textColor=MUTED, alignment=TA_JUSTIFY, leading=10,
        ),
        "banner": ParagraphStyle(
            "banner", parent=b["Normal"], fontName="Helvetica-Bold",
            fontSize=9, textColor=white, alignment=TA_CENTER, leading=11,
        ),
    }


def letterhead(s):
    e = []
    e.append(Paragraph("ZENI LOAN LIMITED", s["brand"]))
    e.append(Paragraph("Smart Loans. Secure Future.", s["tag"]))
    e.append(Paragraph(
        "Proposed Digital Credit Provider &nbsp;·&nbsp; Republic of Kenya<br/>"
        "Email: zeniloans@gmail.com &nbsp;·&nbsp; Tel: +254 726 109 330",
        s["small_c"],
    ))
    e.append(Spacer(1, 3))
    e.append(HRFlowable(width="100%", thickness=2.2, color=GREEN, spaceAfter=1))
    e.append(HRFlowable(width="100%", thickness=0.6, color=GREEN_DARK, spaceBefore=0, spaceAfter=8))
    return e


def build_main_letter(s):
    e = []
    e += letterhead(s)

    # Ref / date row
    ref_tbl = Table(
        [[
            Paragraph(
                f"<b>Our Ref:</b> ZENI/CBK/LONO/{datetime.now().year}/001<br/>"
                f"<b>Your Ref:</b> [To be advised]",
                s["ref"],
            ),
            Paragraph(f"<b>Date:</b> {TODAY}", s["ref_r"]),
        ]],
        colWidths=[110 * mm, 60 * mm],
    )
    ref_tbl.setStyle(TableStyle([
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
    ]))
    e.append(ref_tbl)
    e.append(Spacer(1, 8))

    e.append(Paragraph("<b>The Governor</b>", s["addr"]))
    e.append(Paragraph("Central Bank of Kenya", s["addr"]))
    e.append(Paragraph("Bank Supervision Department", s["addr"]))
    e.append(Paragraph("Haile Selassie Avenue", s["addr"]))
    e.append(Paragraph("P.O. Box 60000 – 00200", s["addr"]))
    e.append(Paragraph("Nairobi, Kenya", s["addr"]))
    e.append(Spacer(1, 4))
    e.append(Paragraph(
        "<i>Attention: Director, Bank Supervision / Officer-in-Charge, Digital Credit Providers</i>",
        s["foot"],
    ))
    e.append(Spacer(1, 6))

    e.append(Paragraph(
        "RE: REQUEST FOR A LETTER OF NO OBJECTION / REGULATORY CLEARANCE "
        "IN RESPECT OF <br/>ZENI LOAN LIMITED — PROPOSED DIGITAL CREDIT BUSINESS",
        s["re"],
    ))

    e.append(Paragraph("Dear Sir / Madam,", s["body_l"]))

    e.append(Paragraph(
        "We write respectfully on behalf of <b>Zeni Loan Limited</b> (the “<b>Company</b>”), "
        "a private company limited by shares [incorporated / in the process of incorporation] "
        "under the Companies Act of Kenya, to request the Central Bank of Kenya (“<b>CBK</b>”) "
        "to issue a <b>Letter of No Objection</b> (or such other form of regulatory clearance "
        "or acknowledgment as the Bank may deem appropriate) in connection with the Company’s "
        "intention to establish and operate a <b>digital credit</b> business in the Republic of Kenya.",
        s["body"],
    ))

    e.append(Paragraph(
        "This request is made in good faith, in support of lawful company registration / "
        "business onboarding processes and as a preparatory step toward full engagement with "
        "CBK’s Digital Credit Provider (“<b>DCP</b>”) authorisation framework. The Company "
        "undertakes <b>not</b> to commence regulated digital credit origination to the public "
        "until all requisite CBK authorisations (and any other licences) are in place.",
        s["body"],
    ))

    # Particulars table
    e.append(Paragraph("1. Particulars of the Applicant", s["h"]))
    rows = [
        ["Legal name", "Zeni Loan Limited"],
        ["Trading name / brand", "ZENI — Smart Loans. Secure Future."],
        ["Proposed principal activity", "Digital credit (consumer micro-lending) delivered electronically"],
        ["Regulatory perimeter sought", "Authorised Digital Credit Provider under CBK supervision (in due course)"],
        ["Registered / proposed office", "[Insert full physical address, Nairobi / Kenya]"],
        ["Postal address", "[P.O. Box ________, Nairobi]"],
        ["Director (primary contact)", "Loice Nyanjugu Muchiri"],
        ["Telephone", "+254 726 109 330"],
        ["Email", "zeniloans@gmail.com"],
        ["Nationality of director", "[Kenyan — confirm]"],
        ["Company registration no.", "[To be inserted upon incorporation / CR12]"],
    ]
    data = [
        [Paragraph(f"<b>{a}</b>", s["cell_b"]), Paragraph(b, s["cell"])]
        for a, b in rows
    ]
    t = Table(data, colWidths=[52 * mm, 118 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), LIGHT),
        ("BOX", (0, 0), (-1, -1), 0.6, GREEN),
        ("INNERGRID", (0, 0), (-1, -1), 0.3, LINE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("BACKGROUND", (0, 0), (0, -1), HexColor("#E6F4EF")),
    ]))
    e.append(t)
    e.append(Spacer(1, 6))

    e.append(Paragraph("2. Nature of the Proposed Business", s["h"]))
    e.append(Paragraph(
        "The Company proposes to offer short-tenor, Kenya Shilling–denominated digital micro-loans "
        "to eligible adult customers through a mobile application and related electronic channels. "
        "Disbursement and repayment are intended to be effected primarily via licensed mobile money "
        "rails (including M-Pesa), subject to commercial contracts and full regulatory compliance. "
        "Product parameters at launch are expected to include conservative ticket sizes (indicatively "
        "KES 5,000 to KES 35,000 on a behavioural ladder), clear pre-contract disclosure of the "
        "total cost of credit, and collections practices that respect customer dignity and the law.",
        s["body"],
    ))

    e.append(Paragraph("3. Purpose of this Request", s["h"]))
    e.append(Paragraph(
        "We kindly request that CBK issue a Letter of No Objection or written guidance confirming, "
        "to the extent the Bank is able, that:",
        s["body"],
    ))
    for b in [
        "The Bank has <b>no objection</b> to the Company proceeding with incorporation and "
        "organisational set-up in Kenya for the purpose of <i>preparing</i> to apply for "
        "authorisation as a Digital Credit Provider;",
        "The Company may continue to develop its governance, capitalisation, ICT, consumer-protection "
        "and compliance arrangements in anticipation of a formal DCP licence application; and",
        "The Bank will advise the Company of any additional information, forms, capital expectations "
        "or conditions required at this pre-application / application stage.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))
    e.append(Paragraph(
        "We understand that a Letter of No Objection, if issued, does <b>not</b> itself constitute "
        "a licence to lend, does <b>not</b> waive any statutory requirement, and does <b>not</b> "
        "replace the separate Digital Credit Provider authorisation process administered by CBK.",
        s["body"],
    ))

    e.append(Paragraph("4. Commitments of the Company", s["h"]))
    e.append(Paragraph("The Company and its directors commit to:", s["body"]))
    for b in [
        "Operate only within activities lawfully authorised by CBK and other competent authorities;",
        "Uphold fair treatment of customers, transparent pricing, responsible collections and effective complaints handling;",
        "Implement AML/CFT controls, data-protection safeguards under the Kenya Data Protection Act, "
        "and information-security standards appropriate to a regulated lender;",
        "Maintain fit-and-proper directors and key officers, and disclose ultimate beneficial ownership as required;",
        "Submit a complete DCP application pack (business plan, policies, capital evidence, ICT documentation) "
        "at the appropriate time; and",
        "Cooperate fully with CBK supervision, inspections and information requests.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Paragraph("5. Supporting Information", s["h"]))
    e.append(Paragraph(
        "We are ready to furnish, upon request or with the formal application: certified incorporation "
        "documents (or name reservation); directors’ identification and CVs; proposed shareholding "
        "and source-of-funds statements; draft Business Plan; ICT / cybersecurity outline; and "
        "consumer documentation templates. A detailed Business Plan and related governance instruments "
        "are available and can be delivered with this letter or under separate cover.",
        s["body"],
    ))

    e.append(Paragraph("6. Prayer", s["h"]))
    e.append(Paragraph(
        "In light of the foregoing, we respectfully request the Central Bank of Kenya’s "
        "<b>favourable consideration</b> and issuance of a <b>Letter of No Objection</b> "
        "(or equivalent written guidance) to facilitate the Company’s lawful set-up and "
        "progression toward Digital Credit Provider authorisation.",
        s["body"],
    ))
    e.append(Paragraph(
        "We remain available for a meeting at the Bank’s convenience and will promptly provide "
        "any further particulars the Bank may require.",
        s["body"],
    ))

    e.append(Paragraph(
        "Please address all correspondence on this matter to the undersigned.",
        s["body"],
    ))

    e.append(Spacer(1, 4))
    e.append(Paragraph("Yours faithfully,", s["sign"]))
    e.append(Paragraph("<b>FOR AND ON BEHALF OF ZENI LOAN LIMITED</b>", s["sign"]))
    e.append(Spacer(1, 14))
    e.append(Paragraph("________________________________________", s["sign"]))
    e.append(Paragraph("<b>Loice Nyanjugu Muchiri</b>", s["sign"]))
    e.append(Paragraph("Director", s["sign"]))
    e.append(Paragraph("Zeni Loan Limited", s["sign"]))
    e.append(Paragraph(f"Date: {TODAY}", s["sign"]))
    e.append(Paragraph("Tel: +254 726 109 330 &nbsp;|&nbsp; Email: zeniloans@gmail.com", s["sign"]))
    e.append(Spacer(1, 10))

    e.append(Paragraph("<b>Enclosures (as applicable):</b>", s["sign"]))
    for b in [
        "Copy of national identity card / passport of Director;",
        "Name reservation / certificate of incorporation (when available);",
        "Business Plan (summary or full version);",
        "Board resolution authorising this request (if already passed).",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Spacer(1, 8))
    e.append(HRFlowable(width="100%", thickness=0.5, color=LINE, spaceAfter=4))
    e.append(Paragraph(
        "Company stamp / seal (if affixed): ______________________________",
        s["sign"],
    ))
    e.append(Spacer(1, 8))
    e.append(Paragraph(
        "This letter is submitted for regulatory engagement with the Central Bank of Kenya. "
        "It does not constitute legal advice. Final filings should be reviewed by Kenya-qualified "
        "advocates and aligned to the CBK Digital Credit Provider regulations and guidance in force "
        "at the date of submission. Placeholders in [square brackets] must be completed before dispatch.",
        s["foot"],
    ))
    return e


def build_guidance_page(s):
    e = []
    e.append(Paragraph("APPENDIX — Improvements Made & Filing Notes", s["re"]))
    e.append(Paragraph(
        "This improved letter replaces the prior one-page draft. Key upgrades for CBK presentation:",
        s["body"],
    ))
    for b in [
        "<b>Name consistency:</b> Removed the error where the RE-line said “Lenda Loan Limited” while "
        "particulars said “Zeni Loan Limited”. The entire letter now uses <b>Zeni Loan Limited</b> only.",
        "<b>Correct addressee block:</b> Governor, CBK, Bank Supervision, physical avenue + P.O. Box, "
        "with attention line to Digital Credit Providers unit.",
        "<b>Accurate regulatory framing:</b> LONO is framed as pre-application / set-up support, "
        "explicitly <i>not</i> a licence to lend. Commitment not to originate regulated credit until authorised.",
        "<b>Substance:</b> Particulars table, nature of business, purpose of request, formal commitments "
        "(consumer protection, AML/CFT, data protection, fit-and-proper, UBO), prayer clause, enclosures.",
        "<b>Professional form:</b> Our Ref / Your Ref, letterhead, structured sections, signature block "
        "with named director (Loice Nyanjugu Muchiri), phone in international format.",
        "<b>Honesty on email:</b> Existing Gmail retained as supplied; recommend adopting a company domain "
        "(e.g. compliance@zeni.co.ke) before formal licence application for institutional credibility.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Spacer(1, 6))
    e.append(Paragraph("Before you print and deliver", s["h"]))
    for b in [
        "Fill registered office, P.O. Box, nationality, and company number.",
        "Print on company letterhead if available; wet-ink signature + optional company stamp.",
        "Attach ID copy and any incorporation papers you already hold.",
        "Deliver via CBK’s prescribed channel (registry / licensing desk / e-portal as advised) and keep a received copy.",
        "Retain Kenya counsel; CBK practice and forms are updated from time to time.",
    ]:
        e.append(Paragraph(f"• {b}", s["bullet"]))

    e.append(Spacer(1, 10))
    e.append(HRFlowable(width="100%", thickness=1, color=GREEN))
    e.append(Spacer(1, 6))
    e.append(Paragraph("— End of improved letter pack —", s["tag"]))
    return e


def build():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=14 * mm,
        bottomMargin=14 * mm,
        title="Zeni Loan Limited — Request for Letter of No Objection (CBK)",
        author="Zeni Loan Limited",
        subject="Improved request for CBK Letter of No Objection",
    )
    s = styles()
    story = build_main_letter(s) + [PageBreak()] + build_guidance_page(s)
    doc.build(story)
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    build()
