<?php
/**
 * Contacts Address Book Component
 */
declare(strict_types=1);
?>
<section class="panel-card" id="contactsSection">
    <div class="panel-card-header">
        <div class="panel-title-group">
            <i class="fa-solid fa-address-book" style="color: var(--accent-blue)"></i>
            <div>
                <h3>سجل جهات الاتصال (Contacts Book)</h3>
                <span class="sub-text">استعراض والبحث في أرقام الهواتف المحفوظة على جهاز الطفل</span>
            </div>
        </div>
        <button class="btn btn-outline-sm" onclick="requestContactsSync()">
            <i class="fa-solid fa-arrows-rotate"></i>
            <span>طلب مزامنة جهات الاتصال</span>
        </button>
    </div>

    <!-- Search Input -->
    <div class="table-toolbar">
        <div class="search-input-wrapper" style="width: 100%; max-width: 400px;">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input type="text" id="contactsSearchInput" placeholder="بحث بالاسم أو رقم الهاتف..." oninput="filterContacts(this.value)" class="search-input">
        </div>
    </div>

    <div class="table-responsive">
        <table class="modern-table">
            <thead>
                <tr>
                    <th style="width: 50px;">#</th>
                    <th>الاسم</th>
                    <th>رقم الهاتف</th>
                    <th>البريد الإلكتروني</th>
                    <th>تاريخ المزامنة</th>
                </tr>
            </thead>
            <tbody id="contactsTableBody">
                <tr>
                    <td colspan="5" class="text-center text-muted">جاري تحميل جهات الاتصال...</td>
                </tr>
            </tbody>
        </table>
    </div>
</section>
