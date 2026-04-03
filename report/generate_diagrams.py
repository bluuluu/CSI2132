from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from matplotlib.patches import FancyBboxPatch, Polygon, FancyArrowPatch


OUT_PDF = Path('report/database_relationship_and_er_diagrams.pdf')
OUT_ER_PNG = Path('report/er_diagram.png')
OUT_REL_PNG = Path('report/relational_diagram.png')


@dataclass
class Box:
    name: str
    x: float
    y: float
    w: float
    h: float


def draw_entity(ax, b: Box, subtitle: str | None = None, attr_lines: list[str] | None = None):
    patch = FancyBboxPatch(
        (b.x, b.y), b.w, b.h,
        boxstyle='round,pad=0.01,rounding_size=0.01',
        linewidth=1.3,
        edgecolor='#222222',
        facecolor='#f6f6f6'
    )
    ax.add_patch(patch)
    ax.text(b.x + b.w / 2, b.y + b.h * 0.78, b.name, ha='center', va='center', fontsize=10, fontweight='bold')
    if subtitle:
        ax.text(b.x + b.w / 2, b.y + b.h * 0.58, subtitle, ha='center', va='center', fontsize=7.5)
    if attr_lines:
        y = b.y + b.h * 0.42
        step = b.h * 0.14
        for line in attr_lines:
            ax.text(b.x + b.w / 2, y, line, ha='center', va='center', fontsize=6.2, color='#303030')
            y -= step


def draw_relationship(ax, label: str, x: float, y: float, w: float = 0.07, h: float = 0.04):
    pts = [
        (x, y + h / 2),
        (x + w / 2, y + h),
        (x + w, y + h / 2),
        (x + w / 2, y),
    ]
    poly = Polygon(pts, closed=True, linewidth=1.1, edgecolor='#333333', facecolor='#ffffff')
    ax.add_patch(poly)
    ax.text(x + w / 2, y + h / 2, label, ha='center', va='center', fontsize=7)


def connect(ax, p1, p2, label: str | None = None):
    arr = FancyArrowPatch(p1, p2, arrowstyle='-', linewidth=1.0, color='#333333')
    ax.add_patch(arr)
    if label:
        mx = (p1[0] + p2[0]) / 2
        my = (p1[1] + p2[1]) / 2
        ax.text(mx, my + 0.012, label, fontsize=7, ha='center', va='center', color='#222222')


def draw_table(ax, b: Box, columns: list[str]):
    patch = FancyBboxPatch(
        (b.x, b.y), b.w, b.h,
        boxstyle='round,pad=0.004,rounding_size=0.006',
        linewidth=1.2,
        edgecolor='#222222',
        facecolor='#fbfbfb'
    )
    ax.add_patch(patch)

    head_h = min(0.042, b.h * 0.22)
    ax.plot([b.x, b.x + b.w], [b.y + b.h - head_h, b.y + b.h - head_h], color='#222222', linewidth=1.0)
    ax.text(b.x + b.w / 2, b.y + b.h - head_h / 2, b.name, ha='center', va='center', fontsize=9, fontweight='bold')

    y = b.y + b.h - head_h - 0.008
    step = (b.h - head_h - 0.014) / max(len(columns), 1)
    for c in columns:
        ax.text(b.x + 0.008, y, c, ha='left', va='top', fontsize=7)
        y -= step


def draw_page_er(ax):
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')
    ax.text(0.5, 0.975, 'eHotels ER Diagram (Current Schema)', ha='center', va='top', fontsize=14, fontweight='bold')

    entities = {
        'hotel_chain': Box('HotelChain', 0.05, 0.78, 0.16, 0.12),
        'hotel': Box('Hotel', 0.29, 0.78, 0.16, 0.12),
        'room': Box('Room', 0.53, 0.78, 0.16, 0.12),
        'person': Box('Person', 0.05, 0.56, 0.16, 0.12),
        'customer': Box('Customer', 0.29, 0.56, 0.16, 0.12),
        'employee': Box('Employee', 0.53, 0.56, 0.16, 0.12),
        'auth': Box('AuthAccount', 0.77, 0.56, 0.18, 0.12),
        'booking': Box('Booking', 0.17, 0.30, 0.16, 0.12),
        'renting': Box('Renting', 0.41, 0.30, 0.16, 0.12),
        'payment': Box('Payment', 0.65, 0.30, 0.16, 0.12),
        'archive': Box('Archive', 0.41, 0.10, 0.16, 0.12),
    }

    er_attrs = {
        'hotel_chain': ['chain_id (PK)', 'chain_name', 'central_office_address'],
        'hotel': ['hotel_id (PK), chain_id (FK)', 'hotel_name, category, total_rooms', 'address_line, contact_email, contact_phone'],
        'room': ['room_id (PK), hotel_id (FK)', 'room_number, capacity, base_price', 'amenities, issues, current_status'],
        'person': ['legal_id (PK), id_type', 'first_name, last_name', 'email, phone, address_line'],
        'customer': ['customer_id (PK), legal_id (FK UQ)', 'hotel_id (FK nullable)', 'registration_date'],
        'employee': ['employee_id (PK), legal_id (FK UQ)', 'hotel_id (FK), role_title', 'hired_on, is_manager'],
        'auth': ['account_id (PK), role, username', 'employee_id/customer_id (FK UQ)', 'is_active, created_at'],
        'booking': ['booking_id (PK), room_id/customer_id (FK)', 'created_by_employee_id (FK nullable)', 'start_date, end_date, status'],
        'renting': ['renting_id (PK), room/customer/employee (FK)', 'source_booking_id (FK nullable)', 'start_date, end_date, status'],
        'payment': ['payment_id (PK), renting_id (FK)', 'employee_id (FK)', 'amount, method, paid_at'],
        'archive': ['archive_id (PK), record_type', 'source_booking_id/source_renting_id', 'chain/hotel/room/customer snapshots'],
    }

    for key, e in entities.items():
        subtitle = None
        if key == 'employee':
            subtitle = '(manager is employee role)'
        draw_entity(ax, e, subtitle, er_attrs.get(key))

    draw_relationship(ax, 'has', 0.21, 0.80)
    draw_relationship(ax, 'has', 0.45, 0.80)
    draw_relationship(ax, 'is-a', 0.21, 0.58)
    draw_relationship(ax, 'is-a', 0.45, 0.58)
    draw_relationship(ax, 'books', 0.26, 0.45)
    draw_relationship(ax, 'assigned', 0.50, 0.45)
    draw_relationship(ax, 'for', 0.10, 0.34)
    draw_relationship(ax, 'for', 0.34, 0.34)
    draw_relationship(ax, 'processed', 0.58, 0.34)
    draw_relationship(ax, 'records', 0.41, 0.22)

    # top layer
    connect(ax, (0.19, 0.82), (0.21, 0.82), '1:N')
    connect(ax, (0.28, 0.82), (0.29, 0.82), '1:N')
    connect(ax, (0.43, 0.82), (0.45, 0.82), '1:N')
    connect(ax, (0.52, 0.82), (0.53, 0.82), '1:N')

    # person specializations
    connect(ax, (0.19, 0.60), (0.21, 0.60), '1:0..1')
    connect(ax, (0.28, 0.60), (0.29, 0.60))
    connect(ax, (0.43, 0.60), (0.45, 0.60), '1:0..1')
    connect(ax, (0.52, 0.60), (0.53, 0.60))

    # auth relationships
    connect(ax, (0.67, 0.60), (0.77, 0.60), '1:0..1')
    connect(ax, (0.43, 0.60), (0.77, 0.64), '1:0..1')

    # booking and renting
    connect(ax, (0.36, 0.56), (0.29, 0.49), '1:N')
    connect(ax, (0.60, 0.56), (0.53, 0.49), '1:N')
    connect(ax, (0.33, 0.56), (0.30, 0.47), '1:N')

    connect(ax, (0.24, 0.45), (0.24, 0.38))
    connect(ax, (0.26, 0.45), (0.24, 0.38))

    connect(ax, (0.50, 0.45), (0.48, 0.38))
    connect(ax, (0.52, 0.45), (0.48, 0.38))

    connect(ax, (0.17, 0.34), (0.17, 0.34))
    connect(ax, (0.24, 0.34), (0.24, 0.34))

    connect(ax, (0.31, 0.34), (0.31, 0.34))
    connect(ax, (0.41, 0.34), (0.41, 0.34))

    connect(ax, (0.55, 0.34), (0.65, 0.34), '1:N')
    connect(ax, (0.58, 0.34), (0.58, 0.34))

    # archive from booking/renting
    connect(ax, (0.24, 0.30), (0.48, 0.24), 'status -> completed/cancelled')
    connect(ax, (0.48, 0.30), (0.48, 0.24))
    connect(ax, (0.48, 0.22), (0.48, 0.18), 'history')


def draw_page_relational(ax):
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')
    ax.text(0.5, 0.975, 'eHotels Relational Diagram (PK/FK)', ha='center', va='top', fontsize=14, fontweight='bold')

    tables = {
        'hotel_chain': (Box('hotel_chain', 0.03, 0.75, 0.20, 0.20), [
            'PK chain_id', 'chain_name (UQ)', 'central_office_address', 'contact_email', 'contact_phone'
        ]),
        'hotel': (Box('hotel', 0.28, 0.72, 0.20, 0.26), [
            'PK hotel_id', 'FK chain_id -> hotel_chain.chain_id', 'hotel_name', 'category', 'total_rooms',
            'address_line', 'contact_email', 'contact_phone'
        ]),
        'room': (Box('room', 0.53, 0.70, 0.20, 0.28), [
            'PK room_id',
            'FK hotel_id -> hotel.hotel_id',
            'FK hotel_room_id -> hotel.hotel_id (alias)',
            'room_number',
            'capacity / room_capacity',
            'base_price / price',
            'view + has_sea_view + has_mountain_view',
            'current_status / status',
            'issues / problems',
            'is_extendable / extendable',
            'amenities'
        ]),
        'person': (Box('person', 0.03, 0.42, 0.20, 0.28), [
            'PK legal_id (SIN)',
            'id_type',
            'first_name',
            'last_name',
            'email (UQ)',
            'phone',
            'address_line'
        ]),
        'customer': (Box('customer', 0.28, 0.48, 0.20, 0.18), [
            'PK customer_id',
            'UQ + FK legal_id -> person.legal_id',
            'FK hotel_id -> hotel.hotel_id (nullable)',
            'registration_date'
        ]),
        'employee': (Box('employee', 0.53, 0.48, 0.20, 0.20), [
            'PK employee_id',
            'UQ + FK legal_id -> person.legal_id',
            'FK hotel_id -> hotel.hotel_id',
            'role_title',
            'hired_on',
            'is_manager'
        ]),
        'auth_account': (Box('auth_account', 0.78, 0.45, 0.20, 0.24), [
            'PK account_id',
            'role',
            'username (UQ)',
            'UQ + FK employee_id -> employee.employee_id (nullable)',
            'UQ + FK customer_id -> customer.customer_id (nullable)',
            'password_plain',
            'is_active',
            'created_at'
        ]),
        'booking': (Box('booking', 0.18, 0.13, 0.23, 0.24), [
            'PK booking_id',
            'FK room_id -> room.room_id',
            'FK customer_id -> customer.customer_id',
            'FK created_by_employee_id -> employee.employee_id (nullable)',
            'start_date',
            'end_date',
            'status',
            'created_at'
        ]),
        'renting': (Box('renting', 0.45, 0.10, 0.23, 0.26), [
            'PK renting_id',
            'FK room_id -> room.room_id',
            'FK customer_id -> customer.customer_id',
            'FK employee_id -> employee.employee_id',
            'FK source_booking_id -> booking.booking_id (nullable)',
            'start_date',
            'end_date',
            'status',
            'created_at'
        ]),
        'payment': (Box('payment', 0.72, 0.13, 0.25, 0.20), [
            'PK payment_id', 'FK renting_id -> renting.renting_id', 'FK employee_id -> employee.employee_id',
            'amount', 'method', 'paid_at'
        ]),
        'archive': (Box('archive', 0.03, 0.08, 0.20, 0.24), [
            'PK archive_id', 'record_type',
            'source_booking_id (logical ref, not FK)',
            'source_renting_id (logical ref, not FK)',
            'chain_name, hotel_name, room_number',
            'customer_full_name, customer_legal_id',
            'start_date', 'end_date', 'final_status'
        ]),
    }

    for b, cols in tables.values():
        draw_table(ax, b, cols)

    def arrow(p1, p2):
        ax.add_patch(FancyArrowPatch(p1, p2, arrowstyle='->', mutation_scale=9, linewidth=1.0, color='#222222'))

    def logical_ref(p1, p2, text):
        ax.add_patch(FancyArrowPatch(
            p1, p2,
            arrowstyle='->',
            mutation_scale=8,
            linewidth=1.0,
            linestyle='--',
            color='#666666'
        ))
        mx = (p1[0] + p2[0]) / 2
        my = (p1[1] + p2[1]) / 2
        ax.text(mx, my + 0.012, text, ha='center', va='center', fontsize=7, color='#666666')

    # FK arrows
    arrow((0.38, 0.90), (0.23, 0.84))   # hotel.chain_id -> hotel_chain
    arrow((0.63, 0.84), (0.48, 0.84))   # room.hotel_id -> hotel

    arrow((0.38, 0.58), (0.23, 0.58))   # customer.legal_id -> person
    arrow((0.63, 0.58), (0.23, 0.58))   # employee.legal_id -> person
    arrow((0.63, 0.55), (0.48, 0.80))   # employee.hotel_id -> hotel
    arrow((0.38, 0.55), (0.48, 0.76))   # customer.hotel_id -> hotel

    arrow((0.84, 0.56), (0.73, 0.58))   # auth.employee_id -> employee
    arrow((0.84, 0.52), (0.48, 0.56))   # auth.customer_id -> customer

    arrow((0.28, 0.27), (0.53, 0.80))   # booking.room_id -> room
    arrow((0.30, 0.25), (0.38, 0.52))   # booking.customer_id -> customer
    arrow((0.32, 0.23), (0.63, 0.55))   # booking.created_by_employee_id -> employee

    arrow((0.56, 0.24), (0.63, 0.80))   # renting.room_id -> room
    arrow((0.58, 0.21), (0.38, 0.52))   # renting.customer_id -> customer
    arrow((0.60, 0.18), (0.63, 0.55))   # renting.employee_id -> employee
    arrow((0.54, 0.16), (0.35, 0.20))   # renting.source_booking_id -> booking

    arrow((0.82, 0.21), (0.60, 0.22))   # payment.renting_id -> renting
    arrow((0.80, 0.19), (0.66, 0.55))   # payment.employee_id -> employee

    # Archive carries historical references only (no FK constraints by design)
    logical_ref((0.23, 0.22), (0.18, 0.22), 'historical booking id')
    logical_ref((0.23, 0.15), (0.45, 0.15), 'historical renting id')

    ax.text(0.50, 0.03, 'Manager is represented as employee.is_manager + auth_account.role = manager',
            ha='center', va='bottom', fontsize=8, color='#333333')
    ax.text(
        0.50,
        0.01,
        'Archive intentionally has no FK constraints to booking/renting/customer/room so history survives deletions.',
        ha='center',
        va='bottom',
        fontsize=8,
        color='#333333'
    )
    ax.text(
        0.50,
        0.055,
        'In this schema, no column is both PK and FK at the same time.',
        ha='center',
        va='bottom',
        fontsize=8,
        color='#333333'
    )
    ax.text(
        0.50,
        0.08,
        'Legend: \"UQ + FK\" means UNIQUE and FOREIGN KEY, but not PRIMARY KEY.',
        ha='center',
        va='bottom',
        fontsize=8,
        color='#333333'
    )


def main():
    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)

    # Page 1: ER
    fig1, ax1 = plt.subplots(figsize=(13, 8.2))
    draw_page_er(ax1)
    fig1.tight_layout()
    fig1.savefig(OUT_ER_PNG, dpi=200)

    # Page 2: relational
    fig2, ax2 = plt.subplots(figsize=(13, 8.2))
    draw_page_relational(ax2)
    fig2.tight_layout()
    fig2.savefig(OUT_REL_PNG, dpi=200)

    with PdfPages(OUT_PDF) as pdf:
        pdf.savefig(fig1)
        pdf.savefig(fig2)

    plt.close(fig1)
    plt.close(fig2)

    print(f'Wrote {OUT_PDF}')
    print(f'Wrote {OUT_ER_PNG}')
    print(f'Wrote {OUT_REL_PNG}')


if __name__ == '__main__':
    main()
