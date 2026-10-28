document.addEventListener('DOMContentLoaded', () => {
    const SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

    // Sidebar Mobile Drawer Elements
    const sidebarToggleBtn = document.getElementById('sidebarToggleBtn');
    const sidebarCloseBtn = document.getElementById('sidebarCloseBtn');
    const appSidebar = document.getElementById('appSidebar');
    const sidebarOverlay = document.getElementById('sidebarOverlay');

    if (sidebarToggleBtn && appSidebar) {
        sidebarToggleBtn.addEventListener('click', () => {
            appSidebar.classList.add('open');
            if (sidebarOverlay) sidebarOverlay.classList.add('active');
        });
    }
    if (sidebarCloseBtn && appSidebar) {
        sidebarCloseBtn.addEventListener('click', () => {
            appSidebar.classList.remove('open');
            if (sidebarOverlay) sidebarOverlay.classList.remove('active');
        });
    }
    if (sidebarOverlay && appSidebar) {
        sidebarOverlay.addEventListener('click', () => {
            appSidebar.classList.remove('open');
            sidebarOverlay.classList.remove('active');
        });
    }

    // UI Elements
    const accountsLoader = document.getElementById('accountsLoader');
    const accountsMessage = document.getElementById('accountsMessage');
    const refreshAccountsBtn = document.getElementById('refreshAccountsBtn');
    const periodFilterGroup = document.getElementById('periodFilterGroup');
    const activeCategoryPeriodLabel = document.getElementById('activeCategoryPeriodLabel');

    // 4 Core Stat Cards
    const dailyTotalDisplay = document.getElementById('dailyTotalDisplay');
    const dailyVisitsCount = document.getElementById('dailyVisitsCount');
    const weeklyTotalDisplay = document.getElementById('weeklyTotalDisplay');
    const weeklyVisitsCount = document.getElementById('weeklyVisitsCount');
    const monthlyTotalDisplay = document.getElementById('monthlyTotalDisplay');
    const monthlyVisitsCount = document.getElementById('monthlyVisitsCount');
    const alltimeTotalDisplay = document.getElementById('alltimeTotalDisplay');
    const alltimeVisitsCount = document.getElementById('alltimeVisitsCount');
    const monthNameLabel = document.getElementById('monthNameLabel');

    // Category Cards
    const catConsultationAmount = document.getElementById('catConsultationAmount');
    const catConsultationPercent = document.getElementById('catConsultationPercent');
    const catConsultationBar = document.getElementById('catConsultationBar');
    const catConsultationCount = document.getElementById('catConsultationCount');
    const catConsultationAvg = document.getElementById('catConsultationAvg');

    const catXrayAmount = document.getElementById('catXrayAmount');
    const catXrayPercent = document.getElementById('catXrayPercent');
    const catXrayBar = document.getElementById('catXrayBar');
    const catXrayCount = document.getElementById('catXrayCount');
    const catXrayAvg = document.getElementById('catXrayAvg');

    const catPharmacyAmount = document.getElementById('catPharmacyAmount');
    const catPharmacyPercent = document.getElementById('catPharmacyPercent');
    const catPharmacyBar = document.getElementById('catPharmacyBar');
    const catPharmacyCount = document.getElementById('catPharmacyCount');
    const catPharmacyAvg = document.getElementById('catPharmacyAvg');

    // Payment Modes
    const totalPaymentModeSum = document.getElementById('totalPaymentModeSum');
    const payCashAmount = document.getElementById('payCashAmount');
    const payCashCount = document.getElementById('payCashCount');
    const payUpiAmount = document.getElementById('payUpiAmount');
    const payUpiCount = document.getElementById('payUpiCount');
    const payCardAmount = document.getElementById('payCardAmount');
    const payCardCount = document.getElementById('payCardCount');
    const payPendingAmount = document.getElementById('payPendingAmount');
    const payPendingCount = document.getElementById('payPendingCount');

    // Ledger
    const ledgerTableBody = document.getElementById('ledgerTableBody');
    const ledgerSearchInput = document.getElementById('ledgerSearchInput');
    const paymentFilterSelect = document.getElementById('paymentFilterSelect');
    const printReportBtn = document.getElementById('printReportBtn');
    const exportCsvBtn = document.getElementById('exportCsvBtn');

    // State Variables
    let currentAccountsData = null;
    let currentSelectedPeriod = 'all'; // 'all', 'today', 'week', 'month'
    let allLedgerTransactions = [];

    // Initialize month label
    const now = new Date();
    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    if (monthNameLabel) {
        monthNameLabel.textContent = `${monthNames[now.getMonth()]} ${now.getFullYear()}`;
    }

    // Period buttons listener
    if (periodFilterGroup) {
        periodFilterGroup.querySelectorAll('.period-pill-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                periodFilterGroup.querySelectorAll('.period-pill-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentSelectedPeriod = btn.getAttribute('data-period');
                updateCategoryBreakdown();
                filterAndRenderLedger();
            });
        });
    }

    // Refresh listener
    if (refreshAccountsBtn) {
        refreshAccountsBtn.addEventListener('click', () => {
            loadAccountsData();
        });
    }

    // Ledger Search & Filter listeners
    if (ledgerSearchInput) {
        ledgerSearchInput.addEventListener('input', () => {
            filterAndRenderLedger();
        });
    }
    if (paymentFilterSelect) {
        paymentFilterSelect.addEventListener('change', () => {
            filterAndRenderLedger();
        });
    }

    // Print & Export
    if (printReportBtn) {
        printReportBtn.addEventListener('click', () => {
            window.print();
        });
    }

    if (exportCsvBtn) {
        exportCsvBtn.addEventListener('click', () => {
            exportTransactionsCsv();
        });
    }

    // Main fetch function
    async function loadAccountsData() {
        const role = localStorage.getItem('dental_user_role') || 'admin';
        if (role === 'staff') {
            showLoader(false);
            return;
        }

        showLoader(true);
        hideMessage();

        try {
            // First try dedicated getAccounts action
            let dataLoaded = false;
            try {
                const res = await fetch(`${SCRIPT_URL}?action=getAccounts`);
                const json = await res.json();
                if (json && json.status === 'success' && json.allTime) {
                    currentAccountsData = json;
                    allLedgerTransactions = json.transactions || [];
                    dataLoaded = true;
                }
            } catch (apiErr) {
                console.log('getAccounts action notice, checking fallback...', apiErr);
            }

            // Fallback: If getAccounts is not yet deployed on Google Apps Script, compute from getPatients
            if (!dataLoaded) {
                const pRes = await fetch(`${SCRIPT_URL}?action=getPatients`);
                const pJson = await pRes.json();
                if (pJson && pJson.status === 'success' && Array.isArray(pJson.data)) {
                    currentAccountsData = computeAccountsFromPatients(pJson.data);
                    allLedgerTransactions = currentAccountsData.transactions;
                    dataLoaded = true;
                } else {
                    throw new Error(pJson.message || 'Could not fetch records from Google Sheets');
                }
            }

            renderDashboardOverview();
            updateCategoryBreakdown();
            filterAndRenderLedger();

        } catch (err) {
            console.error('Accounts loading error:', err);
            showMessage('Error loading financial accounts: ' + (err.message || 'Check network connection.'), 'error');
        } finally {
            showLoader(false);
        }
    }

    // Compute Accounts in-browser if backend is older version
    function computeAccountsFromPatients(patientsList) {
        const nowDate = new Date();
        const y = nowDate.getFullYear();
        const m = ('0' + (nowDate.getMonth() + 1)).slice(-2);
        const d = ('0' + nowDate.getDate()).slice(-2);
        const todayStr = `${y}-${m}-${d}`;
        const monthPrefix = `${y}-${m}`;

        // Monday of current week
        const dayOfWeek = nowDate.getDay();
        const diffToMonday = (dayOfWeek === 0 ? -6 : 1) - dayOfWeek;
        const monday = new Date(nowDate.getFullYear(), nowDate.getMonth(), nowDate.getDate() + diffToMonday);
        const monY = monday.getFullYear();
        const monM = ('0' + (monday.getMonth() + 1)).slice(-2);
        const monD = ('0' + monday.getDate()).slice(-2);
        const mondayStr = `${monY}-${monM}-${monD}`;

        const daily = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };
        const weekly = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };
        const monthly = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };
        const allTime = { total: 0, consultation: 0, xray: 0, pharmacy: 0, count: 0 };

        const paymentModes = { Cash: 0, UPI: 0, Card: 0, Pending: 0, Other: 0 };
        const transactions = [];

        patientsList.forEach(patient => {
            const visits = Array.isArray(patient.visits) ? patient.visits : [];
            visits.forEach(v => {
                const ts = (v.timestamp || '').toString();
                let dateStr = ts.slice(0, 10);
                if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) {
                    const parsed = new Date(ts);
                    if (!isNaN(parsed.getTime())) {
                        dateStr = `${parsed.getFullYear()}-${('0' + (parsed.getMonth() + 1)).slice(-2)}-${('0' + parsed.getDate()).slice(-2)}`;
                    }
                }

                let consult = parseFloat(v.consultationCharge) || 0;
                let doc = (v.doctorConsulted || patient.doctorConsulted || '').trim();
                if (typeof v.consultationCharge === 'string' && v.consultationCharge.toLowerCase().trim() === doc.toLowerCase().trim()) {
                    consult = 0;
                }
                const xray = parseFloat(v.xrayCharge) || 0;
                const pharm = parseFloat(v.pharmacyCharge) || 0;
                const tot = parseFloat(v.totalAmount) || (consult + xray + pharm);
                const pMode = (v.paymentMode || 'Cash').trim();
                const invNo = v.invoiceNo || ('INV-' + (ts ? ts.replace(/\D/g, '').slice(0, 8) : Date.now().toString().slice(-6)));

                if (tot <= 0 && consult <= 0 && xray <= 0 && pharm <= 0) return;

                // All Time
                allTime.total += tot;
                allTime.consultation += consult;
                allTime.xray += xray;
                allTime.pharmacy += pharm;
                allTime.count++;

                // Payment mode
                const pmLow = pMode.toLowerCase();
                if (pmLow.includes('upi') || pmLow.includes('online') || pmLow.includes('gpay')) {
                    paymentModes.UPI += tot;
                } else if (pmLow.includes('card')) {
                    paymentModes.Card += tot;
                } else if (pmLow.includes('pending')) {
                    paymentModes.Pending += tot;
                } else if (pmLow.includes('cash')) {
                    paymentModes.Cash += tot;
                } else {
                    paymentModes.Other += tot;
                }

                // Daily
                if (dateStr === todayStr) {
                    daily.total += tot;
                    daily.consultation += consult;
                    daily.xray += xray;
                    daily.pharmacy += pharm;
                    daily.count++;
                }

                // Weekly
                if (dateStr >= mondayStr && dateStr <= todayStr) {
                    weekly.total += tot;
                    weekly.consultation += consult;
                    weekly.xray += xray;
                    weekly.pharmacy += pharm;
                    weekly.count++;
                }

                // Monthly
                if (dateStr.startsWith(monthPrefix)) {
                    monthly.total += tot;
                    monthly.consultation += consult;
                    monthly.xray += xray;
                    monthly.pharmacy += pharm;
                    monthly.count++;
                }

                transactions.push({
                    invoiceNo: invNo,
                    date: ts || dateStr,
                    dateStr: dateStr,
                    patientName: patient.fullName || 'Patient',
                    phone: patient.phone || '',
                    doctorConsulted: doc || 'Doctor',
                    consultationCharge: consult,
                    xrayCharge: xray,
                    pharmacyCharge: pharm,
                    totalAmount: tot,
                    paymentMode: pMode
                });
            });
        });

        transactions.sort((a, b) => (b.date || '').localeCompare(a.date || ''));

        return {
            status: 'success',
            daily: daily,
            weekly: weekly,
            monthly: monthly,
            allTime: allTime,
            paymentModes: paymentModes,
            transactions: transactions,
            todayDate: todayStr,
            currentMonth: monthPrefix
        };
    }

    // Render 4-metric overview cards
    function renderDashboardOverview() {
        if (!currentAccountsData) return;

        const d = currentAccountsData.daily || { total: 0, count: 0 };
        const w = currentAccountsData.weekly || { total: 0, count: 0 };
        const m = currentAccountsData.monthly || { total: 0, count: 0 };
        const a = currentAccountsData.allTime || { total: 0, count: 0 };

        dailyTotalDisplay.textContent = `₹${(d.total || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        dailyVisitsCount.textContent = `${d.count || 0} invoice${d.count === 1 ? '' : 's'}`;

        weeklyTotalDisplay.textContent = `₹${(w.total || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        weeklyVisitsCount.textContent = `${w.count || 0} invoice${w.count === 1 ? '' : 's'}`;

        monthlyTotalDisplay.textContent = `₹${(m.total || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        monthlyVisitsCount.textContent = `${m.count || 0} invoice${m.count === 1 ? '' : 's'}`;

        alltimeTotalDisplay.textContent = `₹${(a.total || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        alltimeVisitsCount.textContent = `${a.count || 0} total visit${a.count === 1 ? '' : 's'}`;

        // Payment Modes
        renderPaymentModes();
    }

    // Render Category Breakdown (Consultation, X-Ray, Pharmacy) based on currentSelectedPeriod
    function updateCategoryBreakdown() {
        if (!currentAccountsData) return;

        let activeMetrics = currentAccountsData.allTime;
        let periodName = 'All-Time';

        if (currentSelectedPeriod === 'today') {
            activeMetrics = currentAccountsData.daily;
            periodName = 'Today';
        } else if (currentSelectedPeriod === 'week') {
            activeMetrics = currentAccountsData.weekly;
            periodName = 'This Week';
        } else if (currentSelectedPeriod === 'month') {
            activeMetrics = currentAccountsData.monthly;
            periodName = 'This Month';
        }

        if (activeCategoryPeriodLabel) {
            activeCategoryPeriodLabel.textContent = periodName;
        }

        const tot = activeMetrics.total || 0;
        const consult = activeMetrics.consultation || 0;
        const xray = activeMetrics.xray || 0;
        const pharm = activeMetrics.pharmacy || 0;
        const count = activeMetrics.count || 0;

        const consultPct = tot > 0 ? ((consult / tot) * 100).toFixed(1) : '0';
        const xrayPct = tot > 0 ? ((xray / tot) * 100).toFixed(1) : '0';
        const pharmPct = tot > 0 ? ((pharm / tot) * 100).toFixed(1) : '0';

        // Consultation
        catConsultationAmount.textContent = `₹${consult.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        catConsultationPercent.textContent = `${consultPct}%`;
        catConsultationBar.style.width = `${Math.min(100, consultPct)}%`;
        catConsultationCount.textContent = count;
        catConsultationAvg.textContent = `₹${count > 0 ? (consult / count).toFixed(2) : '0.00'}`;

        // X-Ray
        catXrayAmount.textContent = `₹${xray.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        catXrayPercent.textContent = `${xrayPct}%`;
        catXrayBar.style.width = `${Math.min(100, xrayPct)}%`;
        catXrayCount.textContent = count;
        catXrayAvg.textContent = `₹${count > 0 ? (xray / count).toFixed(2) : '0.00'}`;

        // Pharmacy
        catPharmacyAmount.textContent = `₹${pharm.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        catPharmacyPercent.textContent = `${pharmPct}%`;
        catPharmacyBar.style.width = `${Math.min(100, pharmPct)}%`;
        catPharmacyCount.textContent = count;
        catPharmacyAvg.textContent = `₹${count > 0 ? (pharm / count).toFixed(2) : '0.00'}`;
    }

    // Render Payment Modes
    function renderPaymentModes() {
        const pm = currentAccountsData.paymentModes || { Cash: 0, UPI: 0, Card: 0, Pending: 0 };
        const cash = pm.Cash || 0;
        const upi = pm.UPI || 0;
        const card = pm.Card || 0;
        const pending = pm.Pending || 0;
        const total = cash + upi + card + pending + (pm.Other || 0);

        payCashAmount.textContent = `₹${cash.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        payUpiAmount.textContent = `₹${upi.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        payCardAmount.textContent = `₹${card.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        payPendingAmount.textContent = `₹${pending.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

        if (totalPaymentModeSum) {
            totalPaymentModeSum.textContent = `Total Received & Pending: ₹${total.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        }

        // Count transactions per mode
        let cCash = 0, cUpi = 0, cCard = 0, cPending = 0;
        allLedgerTransactions.forEach(t => {
            const m = (t.paymentMode || '').toLowerCase();
            if (m.includes('upi') || m.includes('online')) cUpi++;
            else if (m.includes('card')) cCard++;
            else if (m.includes('pending')) cPending++;
            else if (m.includes('cash')) cCash++;
        });

        payCashCount.textContent = `${cCash} transaction${cCash === 1 ? '' : 's'}`;
        payUpiCount.textContent = `${cUpi} transaction${cUpi === 1 ? '' : 's'}`;
        payCardCount.textContent = `${cCard} transaction${cCard === 1 ? '' : 's'}`;
        payPendingCount.textContent = `${cPending} transaction${cPending === 1 ? '' : 's'}`;
    }

    // Filter and render the transaction ledger table
    function filterAndRenderLedger() {
        if (!ledgerTableBody) return;

        const q = (ledgerSearchInput ? ledgerSearchInput.value : '').toLowerCase().trim();
        const mode = (paymentFilterSelect ? paymentFilterSelect.value : 'all').toLowerCase();

        const todayStr = currentAccountsData ? currentAccountsData.todayDate : '';
        const monthPrefix = currentAccountsData ? currentAccountsData.currentMonth : '';

        const filtered = allLedgerTransactions.filter(t => {
            // Period filter
            if (currentSelectedPeriod === 'today' && t.dateStr !== todayStr) return false;
            if (currentSelectedPeriod === 'month' && !t.dateStr.startsWith(monthPrefix)) return false;

            // Mode filter
            if (mode !== 'all') {
                const tMode = (t.paymentMode || '').toLowerCase();
                if (mode === 'cash' && !tMode.includes('cash')) return false;
                if (mode === 'upi' && !tMode.includes('upi') && !tMode.includes('online')) return false;
                if (mode === 'card' && !tMode.includes('card')) return false;
                if (mode === 'pending' && !tMode.includes('pending')) return false;
            }

            // Text search
            if (q) {
                const pName = (t.patientName || '').toLowerCase();
                const pPhone = (t.phone || '').toLowerCase();
                const doc = (t.doctorConsulted || '').toLowerCase();
                const inv = (t.invoiceNo || '').toLowerCase();
                if (!pName.includes(q) && !pPhone.includes(q) && !doc.includes(q) && !inv.includes(q)) {
                    return false;
                }
            }

            return true;
        });

        if (filtered.length === 0) {
            ledgerTableBody.innerHTML = `
                <tr>
                    <td colspan="10" style="text-align: center; padding: 2.5rem; color: #64748b;">
                        <span>🧾 No billing transactions found matching your criteria.</span>
                    </td>
                </tr>
            `;
            return;
        }

        ledgerTableBody.innerHTML = filtered.map(t => {
            const consult = parseFloat(t.consultationCharge) || 0;
            const xray = parseFloat(t.xrayCharge) || 0;
            const pharm = parseFloat(t.pharmacyCharge) || 0;
            const tot = parseFloat(t.totalAmount) || 0;

            let badgeStyle = 'background: #dcfce7; color: #15803d;';
            const m = (t.paymentMode || '').toLowerCase();
            if (m.includes('pending')) badgeStyle = 'background: #fee2e2; color: #b91c1c;';
            else if (m.includes('upi')) badgeStyle = 'background: #e0f2fe; color: #0284c7;';
            else if (m.includes('card')) badgeStyle = 'background: #f3e8ff; color: #7c3aed;';

            return `
                <tr>
                    <td style="font-weight: 500;">${escapeHtml(t.date || t.dateStr || '')}</td>
                    <td style="font-weight: 700; color: #1e3a8a;">${escapeHtml(t.invoiceNo || '')}</td>
                    <td>
                        <strong>${escapeHtml(t.patientName || 'Patient')}</strong>
                        ${t.phone ? `<div style="font-size: 0.78rem; color: #64748b;">${escapeHtml(t.phone)}</div>` : ''}
                    </td>
                    <td>${escapeHtml(t.doctorConsulted || 'Doctor')}</td>
                    <td class="amount-col">₹${consult.toFixed(2)}</td>
                    <td class="amount-col">₹${xray.toFixed(2)}</td>
                    <td class="amount-col">₹${pharm.toFixed(2)}</td>
                    <td class="amount-col total-col">₹${tot.toFixed(2)}</td>
                    <td>
                        <span style="display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.75rem; font-weight: 700; ${badgeStyle}">
                            ${escapeHtml(t.paymentMode || 'Cash')}
                        </span>
                    </td>
                    <td>
                        <a href="search.html?phone=${encodeURIComponent(t.phone || '')}&name=${encodeURIComponent(t.patientName || '')}&invoice=${encodeURIComponent(t.invoiceNo || '')}&openInvoice=true" class="mini-btn" style="background: #0d9488; color: white; padding: 4px 10px; border-radius: 6px; font-size: 0.78rem; text-decoration: none; display: inline-flex; align-items: center; gap: 4px;" title="View Official Hospital Invoice">
                            <span>🧾</span> Invoice
                        </a>
                    </td>
                </tr>
            `;
        }).join('');
    }

    // Export CSV
    function exportTransactionsCsv() {
        if (!allLedgerTransactions || allLedgerTransactions.length === 0) {
            alert('No transaction records available to export.');
            return;
        }

        const headers = ['Date', 'Invoice No', 'Patient Name', 'Phone', 'Doctor Consulted', 'Consultation Charge (INR)', 'X-Ray Charge (INR)', 'Pharmacy Charge (INR)', 'Total Amount (INR)', 'Payment Mode'];
        const csvRows = [headers.join(',')];

        allLedgerTransactions.forEach(t => {
            const row = [
                `"${(t.date || '').replace(/"/g, '""')}"`,
                `"${(t.invoiceNo || '').replace(/"/g, '""')}"`,
                `"${(t.patientName || '').replace(/"/g, '""')}"`,
                `"${(t.phone || '').replace(/"/g, '""')}"`,
                `"${(t.doctorConsulted || '').replace(/"/g, '""')}"`,
                (parseFloat(t.consultationCharge) || 0).toFixed(2),
                (parseFloat(t.xrayCharge) || 0).toFixed(2),
                (parseFloat(t.pharmacyCharge) || 0).toFixed(2),
                (parseFloat(t.totalAmount) || 0).toFixed(2),
                `"${(t.paymentMode || '').replace(/"/g, '""')}"`
            ];
            csvRows.push(row.join(','));
        });

        const csvContent = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csvRows.join('\n'));
        const downloadAnchor = document.createElement('a');
        downloadAnchor.setAttribute('href', csvContent);
        downloadAnchor.setAttribute('download', `DentalCare_Financial_Report_${new Date().toISOString().slice(0, 10)}.csv`);
        document.body.appendChild(downloadAnchor);
        downloadAnchor.click();
        downloadAnchor.remove();
    }

    function showLoader(show) {
        if (accountsLoader) accountsLoader.style.display = show ? 'block' : 'none';
        if (refreshAccountsBtn) refreshAccountsBtn.disabled = show;
    }

    function showMessage(msg, type) {
        if (!accountsMessage) return;
        accountsMessage.textContent = msg;
        accountsMessage.className = `message-banner ${type === 'error' ? 'error' : 'success'}`;
        accountsMessage.style.display = 'block';
    }

    function hideMessage() {
        if (accountsMessage) accountsMessage.style.display = 'none';
    }

    function escapeHtml(str) {
        if (!str) return '';
        return str.toString()
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    // Initial Load
    loadAccountsData();

    window.addEventListener('dental_role_changed', (e) => {
        if (e.detail && e.detail.role === 'admin') {
            loadAccountsData();
        }
    });
});
