/**
 * Dental Care Clinic & Hospital
 * Search Patient Records & Clinical History Controller
 */
document.addEventListener('DOMContentLoaded', () => {
    // Google Apps Script Web App URL
    const SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

    // Search Controls
    const searchBtn = document.getElementById('searchBtn');
    const searchQuery = document.getElementById('searchQuery');
    const searchClearBtn = document.getElementById('searchClearBtn');
    const searchLoader = document.getElementById('searchLoader');
    const searchSkeleton = document.getElementById('searchSkeleton');
    const searchMessage = document.getElementById('searchMessage');
    const searchResults = document.getElementById('searchResults');
    const searchEmptyState = document.getElementById('searchEmptyState');
    const emptyStateText = document.getElementById('emptyStateText');
    const toastContainer = document.getElementById('toastContainer');

    // Recent Searches & Filter Chips
    const recentSearchesBox = document.getElementById('recentSearchesBox');
    const recentSearchesList = document.getElementById('recentSearchesList');
    const filterChips = document.querySelectorAll('.search-filter-chip');
    let currentFilter = 'all';

    // Patient Summary Hero Elements
    const heroAvatar = document.getElementById('heroAvatar');
    const heroPatientName = document.getElementById('heroPatientName');
    const heroPhone = document.getElementById('heroPhone');
    const heroEmail = document.getElementById('heroEmail');
    const heroGender = document.getElementById('heroGender');
    const heroDob = document.getElementById('heroDob');
    const heroOp = document.getElementById('heroOp');
    const heroVisitsCount = document.getElementById('heroVisitsCount');
    const heroTotalBilled = document.getElementById('heroTotalBilled');

    // Profile, Invoices & Timeline Elements
    const profileGrid = document.getElementById('profileGrid');
    const visitTimeline = document.getElementById('visitTimeline');
    const patientInvoicesList = document.getElementById('patientInvoicesList');
    const printBtn = document.getElementById('printBtn');
    const patientSelectorBar = document.getElementById('patientSelectorBar');
    const patientSelectorPills = document.getElementById('patientSelectorPills');

    // View Invoice Modal Elements
    const invoiceModalOverlay = document.getElementById('invoiceModalOverlay');
    const closeInvoiceModalBtn = document.getElementById('closeInvoiceModalBtn');
    const doneInvoiceBtn = document.getElementById('doneInvoiceBtn');
    const printInvoiceBtn = document.getElementById('printInvoiceBtn');
    const downloadInvoiceBtn = document.getElementById('downloadInvoiceBtn');
    const editInvoiceChargesBtn = document.getElementById('editInvoiceChargesBtn');

    // View Invoice Modal Fields
    const invoicePaper = document.getElementById('invoicePaper');
    const toggleBwModeBtn = document.getElementById('toggleBwModeBtn');
    const invModalNumber = document.getElementById('invModalNumber');
    const invModalDate = document.getElementById('invModalDate');
    const invModalPatientName = document.getElementById('invModalPatientName');
    const invModalPhone = document.getElementById('invModalPhone');
    const invModalDob = document.getElementById('invModalDob');
    const invModalDoctor = document.getElementById('invModalDoctor');
    const invModalPayment = document.getElementById('invModalPayment');
    const invModalConsultation = document.getElementById('invModalConsultation');
    const invModalXray = document.getElementById('invModalXray');
    const invModalPharmacy = document.getElementById('invModalPharmacy');
    const invModalTotal = document.getElementById('invModalTotal');
    const invDriveNotice = document.getElementById('invDriveNotice');
    const invDriveLink = document.getElementById('invDriveLink');

    // Create Invoice Modal Elements
    const createInvoiceModalOverlay = document.getElementById('createInvoiceModalOverlay');
    const closeCreateInvModalBtn = document.getElementById('closeCreateInvModalBtn');
    const cancelCreateInvBtn = document.getElementById('cancelCreateInvBtn');
    const createInvoiceForm = document.getElementById('createInvoiceForm');
    const createInvConsultation = document.getElementById('createInvConsultation');
    const createInvXray = document.getElementById('createInvXray');
    const createInvPharmacy = document.getElementById('createInvPharmacy');
    const createInvPaymentMode = document.getElementById('createInvPaymentMode');
    const createInvDisplayTotal = document.getElementById('createInvDisplayTotal');
    const submitCreateInvBtn = document.getElementById('submitCreateInvBtn');
    const createInvLoader = document.getElementById('createInvLoader');

    let currentSelectedInvoice = null;
    let pendingInvoiceVisit = null;
    let currentPatientProfile = null;
    let cachedInvoicesList = [];

    // 1. Toast Notification Helper
    function showToast(title, message, type = 'success') {
        if (!toastContainer) return;
        const toast = document.createElement('div');
        toast.className = `toast-item ${type}`;

        const iconSymbol = type === 'success' ? '✓' : '⚠️';
        toast.innerHTML = `
            <div class="toast-icon">${iconSymbol}</div>
            <div class="toast-body">
                <div class="toast-title">${escapeHtml(title)}</div>
                <div class="toast-msg">${escapeHtml(message)}</div>
            </div>
            <button type="button" class="toast-close-btn" aria-label="Close notification">&times;</button>
            <div class="toast-progress"></div>
        `;

        toastContainer.appendChild(toast);

        const closeBtn = toast.querySelector('.toast-close-btn');
        const dismiss = () => {
            toast.classList.add('closing');
            setTimeout(() => toast.remove(), 250);
        };

        if (closeBtn) closeBtn.addEventListener('click', dismiss);
        setTimeout(dismiss, 4500);
    }

    // 2. Filter Chips Handler
    filterChips.forEach(chip => {
        chip.addEventListener('click', () => {
            filterChips.forEach(c => c.classList.remove('active'));
            chip.classList.add('active');
            currentFilter = chip.getAttribute('data-filter') || 'all';
            if (searchQuery.value.trim()) {
                performSearch(searchQuery.value.trim());
            }
        });
    });

    // 3. Clear Button Handler
    if (searchClearBtn && searchQuery) {
        searchQuery.addEventListener('input', () => {
            searchClearBtn.style.display = searchQuery.value.trim() ? 'flex' : 'none';
        });

        searchClearBtn.addEventListener('click', () => {
            searchQuery.value = '';
            searchClearBtn.style.display = 'none';
            searchResults.style.display = 'none';
            searchEmptyState.style.display = 'none';
            if (searchMessage) searchMessage.style.display = 'none';
            searchQuery.focus();
        });
    }

    // 4. Recent Searches Management
    function loadRecentSearches() {
        if (!recentSearchesBox || !recentSearchesList) return;
        try {
            const raw = localStorage.getItem('dental_recent_searches');
            const recents = raw ? JSON.parse(raw) : [];
            if (recents.length > 0) {
                recentSearchesList.innerHTML = '';
                recents.slice(0, 6).forEach(q => {
                    const chip = document.createElement('button');
                    chip.type = 'button';
                    chip.className = 'recent-chip';
                    chip.textContent = q;
                    chip.addEventListener('click', () => {
                        searchQuery.value = q;
                        if (searchClearBtn) searchClearBtn.style.display = 'flex';
                        performSearch(q);
                    });
                    recentSearchesList.appendChild(chip);
                });
                recentSearchesBox.style.display = 'flex';
            } else {
                recentSearchesBox.style.display = 'none';
            }
        } catch(e) {}
    }

    function saveRecentSearch(q) {
        if (!q || q.length < 2) return;
        try {
            const raw = localStorage.getItem('dental_recent_searches');
            let recents = raw ? JSON.parse(raw) : [];
            recents = recents.filter(item => item.toLowerCase() !== q.toLowerCase());
            recents.unshift(q);
            localStorage.setItem('dental_recent_searches', JSON.stringify(recents.slice(0, 8)));
            loadRecentSearches();
        } catch(e) {}
    }

    loadRecentSearches();

    // 4b. Load Quick Patient Suggestions from Cached Database
    function loadQuickPatientSuggestions() {
        const box = document.getElementById('quickSuggestionsBox');
        const list = document.getElementById('quickSuggestionsList');
        if (!box || !list) return;
        try {
            const raw = localStorage.getItem('dental_cached_patients');
            if (!raw) {
                box.style.display = 'none';
                return;
            }
            const patients = JSON.parse(raw);
            if (!Array.isArray(patients) || patients.length === 0) {
                box.style.display = 'none';
                return;
            }
            list.innerHTML = '';
            const seen = new Set();
            const unique = [];
            patients.forEach(p => {
                const key = (p.phone || p.fullName || '').toLowerCase().trim();
                if (key && !seen.has(key)) {
                    seen.add(key);
                    unique.push(p);
                }
            });

            unique.slice(0, 6).forEach(p => {
                const chip = document.createElement('button');
                chip.type = 'button';
                chip.className = 'quick-sugg-chip';
                const pPhone = p.phone ? `<span class="quick-chip-phone">${escapeHtml(p.phone)}</span>` : '';
                chip.innerHTML = `<span class="chip-icon">👤</span> <span class="quick-chip-name">${escapeHtml(p.fullName || 'Patient')}</span> ${pPhone}`;
                chip.addEventListener('click', () => {
                    if (searchQuery) {
                        searchQuery.value = p.phone || p.fullName;
                        if (searchClearBtn) searchClearBtn.style.display = 'flex';
                        performSearch(searchQuery.value);
                    }
                });
                list.appendChild(chip);
            });
            box.style.display = unique.length > 0 ? 'flex' : 'none';
        } catch(e) {
            box.style.display = 'none';
        }
    }

    loadQuickPatientSuggestions();

    // 5. Handle URL Parameters for Auto-Search & Auto-Open Invoice
    let autoTargetInvoiceNo = null;
    let shouldAutoOpenInvoice = false;

    try {
        const urlParams = new URLSearchParams(window.location.search);
        const autoQ = urlParams.get('query') || urlParams.get('phone') || urlParams.get('name') || urlParams.get('invoice') || urlParams.get('q');
        autoTargetInvoiceNo = urlParams.get('invoice');
        shouldAutoOpenInvoice = urlParams.get('openInvoice') === 'true' || Boolean(autoTargetInvoiceNo);

        if (autoQ && searchQuery) {
            searchQuery.value = autoQ;
            if (searchClearBtn) searchClearBtn.style.display = 'flex';
            setTimeout(() => { performSearch(autoQ); }, 150);
        }
    } catch(urlErr) {}

    // Handle Enter Key
    searchQuery.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            const q = searchQuery.value.trim();
            if (q) performSearch(q);
        }
    });

    if (searchBtn) {
        searchBtn.addEventListener('click', () => {
            const q = searchQuery.value.trim();
            if (!q) {
                showSearchMessage('Please enter a Patient Name, Phone Number, OP Number, or Invoice Number to search.', 'error');
                return;
            }
            performSearch(q);
        });
    }

    // 6. Main Search Algorithm
    async function performSearch(rawQuery) {
        if (!rawQuery) return;

        // Save recent search
        saveRecentSearch(rawQuery);

        // UI Loading State
        searchBtn.disabled = true;
        searchBtn.querySelector('.btn-text').style.display = 'none';
        searchLoader.style.display = 'block';
        if (searchSkeleton) searchSkeleton.style.display = 'block';
        if (searchMessage) searchMessage.style.display = 'none';
        searchResults.style.display = 'none';
        searchEmptyState.style.display = 'none';

        const qLower = rawQuery.toLowerCase().trim();
        const qDigits = rawQuery.replace(/\D/g, '');
        const qDigits10 = (qDigits.length === 12 && qDigits.startsWith('91')) ? qDigits.slice(2) : qDigits;

        let visits = [];
        let invoices = [];

        try {
            // STEP A: Query Primary Apps Script Endpoint
            try {
                const response = await fetch(`${SCRIPT_URL}?action=search&query=${encodeURIComponent(rawQuery)}`);
                const textResponse = await response.text();
                let result = null;
                try {
                    result = JSON.parse(textResponse);
                } catch(e) {}

                if (result && result.status === 'success' && result.data) {
                    visits = Array.isArray(result.data) ? result.data : [result.data];
                    invoices = Array.isArray(result.invoices) ? result.invoices : [];
                }
            } catch (netErr) {
                console.log('Primary search notice, checking fallback...', netErr);
            }

            // STEP B: Fallback to getPatients if 0 results
            if (visits.length === 0 && invoices.length === 0) {
                try {
                    const fallbackRes = await fetch(`${SCRIPT_URL}?action=getPatients`);
                    const fallbackJson = await fallbackRes.json();

                    if (fallbackJson && fallbackJson.status === 'success' && Array.isArray(fallbackJson.data)) {
                        const matchedVisits = [];
                        const matchedInvoices = [];

                        fallbackJson.data.forEach(p => {
                            const pName = (p.fullName || '').toLowerCase();
                            const pPhone = (p.phone || '').toString();
                            const pDigits = pPhone.replace(/\D/g, '');
                            const pEmail = (p.email || '').toLowerCase();
                            const pOp = (p.opNumber || '').toLowerCase().trim();

                            let patientMatched = false;
                            if (currentFilter === 'name') {
                                patientMatched = pName.includes(qLower);
                            } else if (currentFilter === 'phone') {
                                patientMatched = (qDigits.length >= 4 && (pDigits.includes(qDigits) || qDigits.includes(pDigits))) ||
                                                 (qDigits10.length >= 4 && (pDigits.includes(qDigits10) || qDigits10.includes(pDigits)));
                            } else if (currentFilter === 'op') {
                                patientMatched = pOp && (pOp.includes(qLower) || qLower.includes(pOp));
                            } else {
                                patientMatched = pName.includes(qLower) || pEmail.includes(qLower) || (pOp && (pOp.includes(qLower) || qLower.includes(pOp)));
                                if (!patientMatched && qDigits.length >= 4) {
                                    if (pDigits.includes(qDigits) || qDigits.includes(pDigits)) patientMatched = true;
                                    if (qDigits10.length >= 4 && (pDigits.includes(qDigits10) || qDigits10.includes(pDigits))) patientMatched = true;
                                }
                            }

                            const pVisits = Array.isArray(p.visits) ? p.visits : [];
                            const pInvs = Array.isArray(p.invoices) ? p.invoices : [];

                            // Check visits
                            pVisits.forEach(v => {
                                const invNo = (v.invoiceNo || '').toLowerCase();
                                const doc = (v.doctorConsulted || '').toLowerCase();
                                const vOp = (v.opNumber || '').toLowerCase().trim();
                                const matchesInv = invNo && (invNo.includes(qLower) || qLower.includes(invNo));
                                const matchesOp = vOp && (vOp.includes(qLower) || qLower.includes(vOp));

                                if (patientMatched || matchesInv || matchesOp || (currentFilter === 'all' && doc.includes(qLower))) {
                                    matchedVisits.push({
                                        ...v,
                                        fullName: p.fullName,
                                        phone: p.phone,
                                        email: p.email,
                                        address: p.address || p.email,
                                        dob: p.dob,
                                        age: p.age,
                                        opNumber: v.opNumber || p.opNumber,
                                        gender: p.gender
                                    });
                                }
                            });

                            // Check invoices
                            pInvs.forEach(inv => {
                                const invNo = (inv.invoiceNo || '').toLowerCase();
                                const matchesInv = invNo && (invNo.includes(qLower) || qLower.includes(invNo));
                                if (patientMatched || matchesInv) {
                                    matchedInvoices.push({
                                        ...inv,
                                        patientName: p.fullName,
                                        phone: p.phone,
                                        opNumber: inv.opNumber || p.opNumber
                                    });
                                }
                            });
                        });

                        if (matchedVisits.length > 0 || matchedInvoices.length > 0) {
                            visits = matchedVisits;
                            invoices = matchedInvoices;
                        }
                    }
                } catch(fallbackErr) {
                    console.log('Search fallback notice:', fallbackErr);
                }
            }

            // STEP C: Merge LocalStorage Cached Patients for instant discovery
            try {
                const localRaw = localStorage.getItem('dental_cached_patients');
                if (localRaw) {
                    const localPatients = JSON.parse(localRaw);
                    localPatients.forEach(p => {
                        const pName = (p.fullName || '').toLowerCase();
                        const pPhone = (p.phone || '').toString();
                        const pDigits = pPhone.replace(/\D/g, '');
                        const pEmail = (p.email || '').toLowerCase();

                        const pOp = (p.opNumber || '').toLowerCase().trim();
                        let matched = false;
                        if (currentFilter === 'name') {
                            matched = pName.includes(qLower);
                        } else if (currentFilter === 'phone') {
                            matched = (qDigits.length >= 4 && (pDigits.includes(qDigits) || qDigits.includes(pDigits))) ||
                                      (qDigits10.length >= 4 && (pDigits.includes(qDigits10) || qDigits10.includes(pDigits)));
                        } else if (currentFilter === 'op') {
                            matched = pOp && (pOp.includes(qLower) || qLower.includes(pOp));
                        } else {
                            matched = pName.includes(qLower) || pEmail.includes(qLower) || (pOp && (pOp.includes(qLower) || qLower.includes(pOp)));
                            if (!matched && qDigits.length >= 4) {
                                if (pDigits.includes(qDigits) || qDigits.includes(pDigits)) matched = true;
                                if (qDigits10.length >= 4 && (pDigits.includes(qDigits10) || qDigits10.includes(pDigits))) matched = true;
                            }
                        }

                        if (matched) {
                            const pVisits = Array.isArray(p.visits) ? p.visits : [p];
                            pVisits.forEach(v => {
                                const exists = visits.some(ev => (ev.timestamp === v.timestamp && ev.phone === v.phone) || (ev.invoiceNo && ev.invoiceNo === v.invoiceNo));
                                if (!exists) {
                                    visits.unshift({
                                        ...v,
                                        fullName: p.fullName,
                                        phone: p.phone,
                                        email: p.email,
                                        dob: p.dob,
                                        gender: p.gender
                                    });
                                }
                            });

                            const pInvs = Array.isArray(p.invoices) ? p.invoices : [];
                            pInvs.forEach(inv => {
                                const exists = invoices.some(ei => ei.invoiceNo === inv.invoiceNo);
                                if (!exists) {
                                    invoices.unshift({
                                        ...inv,
                                        patientName: p.fullName,
                                        phone: p.phone
                                    });
                                }
                            });
                        }
                    });
                }
            } catch(localErr) {
                console.warn('Local merge notice:', localErr);
            }

            cachedInvoicesList = invoices;

            // STEP D: Render or Show Empty State
            if (visits.length > 0 || invoices.length > 0) {
                showSearchMessage(`Found ${visits.length} clinical record(s) and ${invoices.length} recorded invoice(s)`, 'success');
                renderResults(visits, invoices);
                searchResults.style.display = 'block';
                searchEmptyState.style.display = 'none';

                // Auto-open requested invoice if URL parameter present
                if (shouldAutoOpenInvoice) {
                    setTimeout(() => {
                        let matchingInv = null;
                        if (autoTargetInvoiceNo) {
                            const cleanTarget = autoTargetInvoiceNo.toLowerCase().trim();
                            matchingInv = invoices.find(i => i.invoiceNo && i.invoiceNo.toLowerCase().trim() === cleanTarget);
                            if (!matchingInv) {
                                const vMatch = visits.find(v => v.invoiceNo && v.invoiceNo.toLowerCase().trim() === cleanTarget);
                                if (vMatch) {
                                    showVisitInvoice(vMatch, currentPatientProfile);
                                    return;
                                }
                            }
                        }

                        if (matchingInv) {
                            showPastInvoiceModal(matchingInv);
                        } else if (invoices.length > 0) {
                            showPastInvoiceModal(invoices[0]);
                        } else if (visits.length > 0) {
                            showVisitInvoice(visits[0], currentPatientProfile);
                        }
                    }, 250);
                }
            } else {
                searchResults.style.display = 'none';
                searchEmptyState.style.display = 'block';
                if (emptyStateText) {
                    emptyStateText.textContent = `No patient records or invoices found in the clinic database for "${rawQuery}". Check contact numbers or register this patient.`;
                }
                showSearchMessage(`No records found for "${rawQuery}".`, 'error');
            }
        } catch (error) {
            console.error('Search error:', error);
            showSearchMessage('Error searching: ' + (error.message || 'Please check network connection.'), 'error');
            showToast('Search Failed', error.message || 'Network error', 'error');
        } finally {
            searchBtn.disabled = false;
            searchBtn.querySelector('.btn-text').style.display = 'block';
            searchLoader.style.display = 'none';
            if (searchSkeleton) searchSkeleton.style.display = 'none';
        }
    }

    // 7. Group Visits by Patient Identity
    function normalizeDateStr(d) {
        if (!d) return '';
        const s = d.toString().trim();
        const m = s.match(/^(\d{4})[^\d]?(\d{1,2})[^\d]?(\d{1,2})/);
        if (m) {
            const pad = n => ('0' + n).slice(-2);
            return `${m[1]}-${pad(m[2])}-${pad(m[3])}`;
        }
        return s.replace(/[^0-9]/g, '');
    }

    function groupVisitsByPatient(visits) {
        const groups = [];
        visits.forEach(v => {
            const cleanName = (v.fullName || v.patientName || '').toLowerCase().replace(/\s+/g, ' ').trim();
            const digits = (v.phone || '').toString().replace(/\D/g, '');
            const rawDob = (v.dob || '').toString().trim();
            const normDob = normalizeDateStr(rawDob);

            let foundGroup = null;
            for (const grp of groups) {
                const gName = (grp.profile.fullName || grp.profile.patientName || '').toLowerCase().replace(/\s+/g, ' ').trim();
                const gDigits = (grp.profile.phone || '').toString().replace(/\D/g, '');
                const gDob = normalizeDateStr(grp.profile.dob);

                // Identity Rule: Same Name and Same Phone is the same individual
                if (cleanName === gName && digits === gDigits) {
                    if (normDob && gDob) {
                        if (normDob === gDob) {
                            foundGroup = grp;
                            break;
                        }
                    } else {
                        foundGroup = grp;
                        if (!grp.profile.dob && rawDob) grp.profile.dob = rawDob;
                        break;
                    }
                }
            }

            if (foundGroup) {
                foundGroup.visits.push(v);
            } else {
                groups.push({
                    profile: { ...v },
                    visits: [v]
                });
            }
        });
        return groups;
    }

    // 8. Render Results
    function renderResults(visits, invoices) {
        const patientGroups = groupVisitsByPatient(visits);

        if (patientGroups.length > 1 && patientSelectorBar && patientSelectorPills) {
            patientSelectorBar.style.display = 'block';
            patientSelectorPills.innerHTML = '';
            patientGroups.forEach((grp, gIdx) => {
                const btn = document.createElement('button');
                btn.type = 'button';
                btn.className = 'search-filter-chip' + (gIdx === 0 ? ' active' : '');
                const pDob = grp.profile.dob ? ` (DOB: ${formatDate(grp.profile.dob)})` : '';
                btn.textContent = (grp.profile.fullName || grp.profile.patientName || 'Patient') + pDob;

                btn.addEventListener('click', () => {
                    patientSelectorPills.querySelectorAll('button').forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');
                    renderSinglePatientResult(grp.profile, grp.visits, invoices);
                });
                patientSelectorPills.appendChild(btn);
            });
            renderSinglePatientResult(patientGroups[0].profile, patientGroups[0].visits, invoices);
        } else {
            if (patientSelectorBar) patientSelectorBar.style.display = 'none';
            const latestInfo = visits.length > 0 ? visits[0] : (invoices.length > 0 ? invoices[0] : {});
            renderSinglePatientResult(latestInfo, visits, invoices);
        }
    }

    function calculateAgeFromDob(dobStr) {
        if (!dobStr) return '';
        try {
            const parts = dobStr.toString().trim().split('-');
            if (parts.length === 3) {
                const birth = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                const today = new Date();
                let age = today.getFullYear() - birth.getFullYear();
                const m = today.getMonth() - birth.getMonth();
                if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
                if (age >= 0 && age < 125) return ` (${age} yrs)`;
            }
        } catch(e) {}
        return '';
    }

    function renderSinglePatientResult(latestInfo, visits, invoices) {
        currentPatientProfile = latestInfo;

        // Compute total billed for this patient
        let totalBilledVal = 0;
        visits.forEach(v => {
            const t = parseFloat(v.totalAmount) || ((parseFloat(v.consultationCharge) || 0) + (parseFloat(v.xrayCharge) || 0) + (parseFloat(v.pharmacyCharge) || 0));
            totalBilledVal += t;
        });

        const pName = latestInfo.fullName || latestInfo.patientName || 'Patient';
        const pGender = latestInfo.gender || 'Not Specified';
        const ageTag = calculateAgeFromDob(latestInfo.dob);
        const phoneClean = (latestInfo.phone || '').toString().trim();
        const emailClean = (latestInfo.email || '').toString().trim();

        // Update Patient Summary Hero Card
        if (heroPatientName) heroPatientName.textContent = pName;
        if (heroPhone) heroPhone.textContent = '📞 ' + (phoneClean || 'N/A');
        if (heroEmail) heroEmail.textContent = '✉️ ' + (emailClean || 'None');
        if (heroGender) heroGender.textContent = '⚧ ' + pGender;
        if (heroDob) heroDob.textContent = '🎂 ' + (formatDate(latestInfo.dob) + ageTag);
        if (heroVisitsCount) heroVisitsCount.textContent = visits.length;
        if (heroTotalBilled) heroTotalBilled.textContent = '₹' + totalBilledVal.toFixed(2);

        if (heroAvatar) {
            heroAvatar.textContent = pGender.toLowerCase().startsWith('m') ? '👨' : (pGender.toLowerCase().startsWith('f') ? '👩' : '👤');
        }

        // Connect Hero Action Links to current patient
        const heroBookAptBtn = document.getElementById('heroBookAptBtn');
        const heroAddRevisitBtn = document.getElementById('heroAddRevisitBtn');
        if (heroBookAptBtn) {
            heroBookAptBtn.href = `appointments.html?name=${encodeURIComponent(pName)}&phone=${encodeURIComponent(phoneClean)}`;
        }
        if (heroAddRevisitBtn) {
            heroAddRevisitBtn.href = `index.html?phone=${encodeURIComponent(phoneClean)}`;
        }

        // Update Invoices and Visits header badges
        const invoicesCountBadge = document.getElementById('invoicesCountBadge');
        if (invoicesCountBadge) {
            invoicesCountBadge.textContent = `${invoices.length} Invoices Recorded`;
        }
        const timelineVisitsBadge = document.getElementById('timelineVisitsBadge');
        if (timelineVisitsBadge) {
            timelineVisitsBadge.textContent = `${visits.length} Visits Logged`;
        }

        const opVal = latestInfo.opNumber || (visits.find(v => v.opNumber) && visits.find(v => v.opNumber).opNumber) || 'N/A';
        if (heroOp) heroOp.textContent = '📋 OP: ' + opVal;

        // 1. Render Profile Grid
        profileGrid.innerHTML = `
            <div class="profile-item">
                <span class="profile-label">Full Name</span>
                <span class="profile-value"><strong>${escapeHtml(pName)}</strong></span>
            </div>
            <div class="profile-item">
                <span class="profile-label">Contact Phone</span>
                <div class="profile-val-row">
                    <span class="profile-value">${escapeHtml(phoneClean) || 'N/A'}</span>
                    ${phoneClean ? `<a href="tel:${escapeHtml(phoneClean)}" class="profile-quick-action" title="Call patient">📞 Call</a>` : ''}
                </div>
            </div>
            <div class="profile-item">
                <span class="profile-label">OP Number</span>
                <span class="profile-value" style="color: #0f766e; font-weight: 700;">📋 ${escapeHtml(opVal)}</span>
            </div>
            <div class="profile-item">
                <span class="profile-label">Address of Patient</span>
                <div class="profile-val-row">
                    <span class="profile-value">${escapeHtml(latestInfo.address || latestInfo.email || 'None provided')}</span>
                </div>
            </div>
            <div class="profile-item">
                <span class="profile-label">Date of Birth / Age</span>
                <span class="profile-value">${formatDate(latestInfo.dob)}${ageTag || (latestInfo.age ? ' (' + latestInfo.age + ' yrs)' : ' (Age N/A)')}</span>
            </div>
            <div class="profile-item">
                <span class="profile-label">Gender</span>
                <span class="profile-value">${escapeHtml(pGender)}</span>
            </div>
            <div class="profile-item">
                <span class="profile-label">Attending Doctor</span>
                <span class="profile-value" style="color: #0f766e; font-weight: 700;">👨‍⚕️ ${escapeHtml(latestInfo.doctorConsulted) || 'General Dentistry'}</span>
            </div>
        `;

        // 2. Render Invoices List
        renderInvoicesList(invoices, visits);

        // 3. Render Visit Timeline
        visitTimeline.innerHTML = '';

        if (visits.length === 0) {
            visitTimeline.innerHTML = `
                <div style="padding: 1.5rem; text-align: center; color: #64748b; background: #f8fafc; border-radius: 12px;">
                    <span>No separate clinical visits found for this profile.</span>
                </div>
            `;
            return;
        }

        visits.forEach((visit, index) => {
            let dateStr = 'Recorded Visit';
            if (visit.timestamp) {
                const d = new Date(visit.timestamp);
                if (!isNaN(d.getTime())) {
                    dateStr = d.toLocaleDateString(undefined, {
                        year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute:'2-digit'
                    });
                } else {
                    dateStr = escapeHtml(visit.timestamp);
                }
            }

            let consultation = parseFloat(visit.consultationCharge);
            if (isNaN(consultation) || (typeof visit.consultationCharge === 'string' && visit.consultationCharge.toLowerCase().trim() === (visit.doctorConsulted || '').toLowerCase().trim())) {
                consultation = 0;
            }
            const xray = parseFloat(visit.xrayCharge) || 0;
            const pharmacy = parseFloat(visit.pharmacyCharge) || 0;
            const total = parseFloat(visit.totalAmount) || (consultation + xray + pharmacy);
            const hasBilling = total > 0 || consultation > 0 || xray > 0 || pharmacy > 0;

            const timelineItem = document.createElement('div');
            timelineItem.className = 'timeline-item';

            let billingHtml = '';
            if (hasBilling) {
                billingHtml = `
                    <div class="timeline-billing">
                        <div class="billing-breakdown">
                            <span class="billing-item-badge">Consultation: ₹${consultation.toFixed(2)}</span>
                            <span class="billing-item-badge">X-Ray: ₹${xray.toFixed(2)}</span>
                            <span class="billing-item-badge">Pharmacy: ₹${pharmacy.toFixed(2)}</span>
                            <span class="billing-total-badge">Total: ₹${total.toFixed(2)}</span>
                        </div>
                        <div class="invoice-btn-group">
                            <button type="button" class="mini-btn btn-invoice-view" data-visit-index="${index}" style="background: #0d9488; color: white;">
                                <span>🧾</span> Show Invoice
                            </button>
                            ${visit.driveFileUrl ? `
                                <a href="${escapeHtml(visit.driveFileUrl)}" target="_blank" class="mini-btn btn-drive-link">
                                    <span>📁</span> Drive
                                </a>
                            ` : ''}
                        </div>
                    </div>
                `;
            } else {
                billingHtml = `
                    <div class="timeline-billing" style="background: #f8fafc; border-color: #e2e8f0;">
                        <span style="font-size: 0.85rem; color: #64748b;">No billing recorded yet for this visit.</span>
                        <div class="invoice-btn-group">
                            <button type="button" class="mini-btn btn-invoice-show" data-visit-index="${index}" style="background: #0d9488; color: white;">
                                <span>🧾</span> Show Invoice
                            </button>
                        </div>
                    </div>
                `;
            }

            timelineItem.innerHTML = `
                <div class="timeline-date">📅 ${dateStr}</div>
                <div class="timeline-content">
                    <div class="visit-detail"><strong>Doctor Consulted:</strong> ${escapeHtml(visit.doctorConsulted) || 'Not Specified'}</div>
                    <div class="visit-detail"><strong>Medical History / Allergies:</strong> ${escapeHtml(visit.medicalHistory) || 'None reported'}</div>
                    <div class="visit-detail"><strong>Past / Current Diseases:</strong> ${escapeHtml(visit.diseaseHistory) || 'None reported'}</div>
                    ${visit.lastVisitDate ? `<div class="visit-detail"><strong>Previous Reported Visit:</strong> ${formatDate(visit.lastVisitDate)}</div>` : ''}
                    ${billingHtml}
                </div>
            `;

            visitTimeline.appendChild(timelineItem);
        });

        // Helper to show registered person's invoice directly
        function handleShowInvoiceForVisit(visit, latestProfile) {
            pendingInvoiceVisit = visit;

            let matchingInv = null;
            if (visit.invoiceNo) {
                matchingInv = cachedInvoicesList.find(inv => inv.invoiceNo && inv.invoiceNo.trim() === visit.invoiceNo.trim());
            }
            if (!matchingInv && visit.timestamp) {
                const vDate = visit.timestamp.toString().slice(0, 10);
                matchingInv = cachedInvoicesList.find(inv =>
                    inv.timestamp && (
                        inv.timestamp.toString().slice(0, 10) === vDate ||
                        inv.timestamp.toString().includes(vDate) ||
                        visit.timestamp.toString().includes(inv.timestamp.toString().slice(0, 10))
                    )
                );
            }

            if (matchingInv) {
                showPastInvoiceModal(matchingInv);
            } else {
                showVisitInvoice(visit, latestProfile);
            }
        }

        // Attach Show Invoice click handlers
        document.querySelectorAll('.btn-invoice-view, .btn-invoice-show').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const idx = parseInt(e.currentTarget.getAttribute('data-visit-index'), 10);
                const visit = visits[idx];
                if (visit) {
                    handleShowInvoiceForVisit(visit, latestInfo);
                }
            });
        });
    }

    function renderInvoicesList(invoices, visits) {
        const allInvoices = [...invoices];

        // Also harvest visits with billing that might not be in the invoices array
        visits.forEach(v => {
            const tot = parseFloat(v.totalAmount) || 0;
            if (tot > 0 || parseFloat(v.consultationCharge) > 0) {
                const alreadyExists = allInvoices.some(inv => (inv.invoiceNo && inv.invoiceNo === v.invoiceNo) || (inv.timestamp === v.timestamp));
                if (!alreadyExists) {
                    allInvoices.push({
                        invoiceNo: v.invoiceNo || 'INV-' + (v.timestamp ? v.timestamp.replace(/[^0-9]/g, '').slice(0, 8) : 'RECORD'),
                        timestamp: v.timestamp,
                        patientName: v.fullName,
                        phone: v.phone,
                        doctorConsulted: v.doctorConsulted,
                        consultationCharge: v.consultationCharge,
                        xrayCharge: v.xrayCharge,
                        pharmacyCharge: v.pharmacyCharge,
                        totalAmount: v.totalAmount,
                        paymentMode: v.paymentMode || 'Cash',
                        driveFileUrl: v.driveFileUrl || ''
                    });
                }
            }
        });

        if (allInvoices.length === 0) {
            patientInvoicesList.innerHTML = `
                <div style="padding: 1.2rem; background: #f8fafc; border-radius: 10px; text-align: center; color: #64748b; font-size: 0.9rem;">
                    <span>🧾 No separate invoices list recorded for this patient yet. Click "Show Invoice" on any visit below to inspect receipt.</span>
                </div>
            `;
            return;
        }

        patientInvoicesList.innerHTML = `
            <div class="invoices-grid">
                ${allInvoices.map((inv, idx) => `
                    <div class="inv-card-box">
                        <div class="inv-card-top">
                            <div class="inv-card-title-row">
                                <span class="inv-badge-no">🧾 ${escapeHtml(inv.invoiceNo)}</span>
                                <span class="inv-badge-paid">PAID</span>
                            </div>
                            <div class="inv-card-date">📅 ${escapeHtml(inv.timestamp)}</div>
                            <div class="inv-card-doctor">👨‍⚕️ ${escapeHtml(inv.doctorConsulted || 'Doctor')}</div>
                            <div class="inv-card-total-row">
                                <span class="lbl">Total Amount:</span>
                                <span class="val">₹${parseFloat(inv.totalAmount || 0).toFixed(2)}</span>
                            </div>
                        </div>
                        <div class="inv-card-actions">
                            <button type="button" class="mini-btn btn-view-past-inv" data-inv-idx="${idx}">
                                <span>🧾</span> View Invoice
                            </button>
                            ${inv.driveFileUrl ? `
                                <a href="${escapeHtml(inv.driveFileUrl)}" target="_blank" class="mini-btn btn-drive-link">
                                    <span>📁</span> Drive
                                </a>
                            ` : ''}
                        </div>
                    </div>
                `).join('')}
            </div>
        `;

        // Attach click handlers
        patientInvoicesList.querySelectorAll('.btn-view-past-inv').forEach(b => {
            b.addEventListener('click', (e) => {
                const idx = parseInt(e.currentTarget.getAttribute('data-inv-idx'), 10);
                const inv = allInvoices[idx];
                if (inv) showPastInvoiceModal(inv);
            });
        });
    }

    function showVisitInvoice(visit, patientProfile) {
        pendingInvoiceVisit = visit;
        const consultation = parseFloat(visit.consultationCharge) || 0;
        const xray = parseFloat(visit.xrayCharge) || 0;
        const pharmacy = parseFloat(visit.pharmacyCharge) || 0;
        const total = parseFloat(visit.totalAmount) || (consultation + xray + pharmacy);

        let doctor = visit.doctorConsulted || (patientProfile ? patientProfile.doctorConsulted : '') || 'Attending Doctor';
        if (doctor.toLowerCase().includes('consulting specialist')) doctor = 'Attending Doctor';

        currentSelectedInvoice = {
            invoiceNo: visit.invoiceNo || ('INV-' + (visit.timestamp ? visit.timestamp.toString().replace(/\D/g, '').slice(0, 8) : Date.now().toString().slice(-6))),
            timestamp: visit.timestamp || 'Recorded Visit',
            fullName: visit.fullName || (patientProfile ? patientProfile.fullName : 'Valued Patient'),
            phone: visit.phone || (patientProfile ? patientProfile.phone : 'N/A'),
            email: visit.email || (patientProfile ? patientProfile.email : 'N/A'),
            doctorConsulted: doctor,
            paymentMode: visit.paymentMode || 'Cash',
            consultationCharge: consultation,
            xrayCharge: xray,
            pharmacyCharge: pharmacy,
            totalAmount: total,
            driveFileUrl: visit.driveFileUrl || ''
        };

        populateAndOpenViewModal(currentSelectedInvoice);
    }

    function showPastInvoiceModal(inv) {
        let doctor = inv.doctorConsulted || (currentPatientProfile ? currentPatientProfile.doctorConsulted : '') || 'Attending Doctor';
        if (doctor.toLowerCase().includes('consulting specialist')) doctor = 'Attending Doctor';

        currentSelectedInvoice = {
            invoiceNo: inv.invoiceNo || ('INV-' + Date.now().toString().slice(-6)),
            timestamp: inv.timestamp || 'Recorded Visit',
            fullName: inv.patientName || (currentPatientProfile ? currentPatientProfile.fullName : 'Valued Patient'),
            phone: inv.phone || (currentPatientProfile ? currentPatientProfile.phone : 'N/A'),
            email: (currentPatientProfile ? currentPatientProfile.email : 'N/A'),
            doctorConsulted: doctor,
            paymentMode: inv.paymentMode || 'Cash',
            consultationCharge: parseFloat(inv.consultationCharge) || 0,
            xrayCharge: parseFloat(inv.xrayCharge) || 0,
            pharmacyCharge: parseFloat(inv.pharmacyCharge) || 0,
            totalAmount: parseFloat(inv.totalAmount) || 0,
            driveFileUrl: inv.driveFileUrl || ''
        };

        populateAndOpenViewModal(currentSelectedInvoice);
    }

    function populateAndOpenViewModal(inv) {
        invModalNumber.textContent = inv.invoiceNo;
        invModalDate.textContent = 'Date: ' + inv.timestamp;
        invModalPatientName.textContent = inv.fullName;
        invModalPhone.textContent = inv.phone;
        const patientAgeOrDob = inv.age ? (inv.age + ' yrs') : (inv.dob || (currentPatientProfile && (currentPatientProfile.age ? (currentPatientProfile.age + ' yrs') : currentPatientProfile.dob)) || 'N/A');
        if (invModalDob) invModalDob.textContent = patientAgeOrDob;
        const invModalOp = document.getElementById('invModalOp');
        if (invModalOp) invModalOp.textContent = inv.opNumber || (currentPatientProfile && currentPatientProfile.opNumber ? ('OP: ' + currentPatientProfile.opNumber) : 'Official Receipt');
        invModalDoctor.textContent = inv.doctorConsulted;
        invModalPayment.textContent = 'PAID (' + inv.paymentMode + ')';

        invModalConsultation.textContent = parseFloat(inv.consultationCharge).toFixed(2);
        invModalXray.textContent = parseFloat(inv.xrayCharge).toFixed(2);
        invModalPharmacy.textContent = parseFloat(inv.pharmacyCharge).toFixed(2);
        invModalTotal.textContent = parseFloat(inv.totalAmount).toFixed(2);

        if (inv.driveFileUrl) {
            invDriveNotice.style.display = 'flex';
            invDriveLink.href = inv.driveFileUrl;
        } else {
            invDriveNotice.style.display = 'none';
        }

        invoiceModalOverlay.classList.add('active');
    }

    function closeInvoiceModal() {
        invoiceModalOverlay.classList.remove('active');
    }

    if (closeInvoiceModalBtn) closeInvoiceModalBtn.addEventListener('click', closeInvoiceModal);
    if (doneInvoiceBtn) doneInvoiceBtn.addEventListener('click', closeInvoiceModal);

    // Toggle Black & White Mode
    if (toggleBwModeBtn && invoicePaper) {
        toggleBwModeBtn.addEventListener('click', () => {
            invoicePaper.classList.toggle('bw-mode');
            toggleBwModeBtn.classList.toggle('active');
            if (invoicePaper.classList.contains('bw-mode')) {
                toggleBwModeBtn.innerHTML = '<span>🌈</span> Color Mode';
            } else {
                toggleBwModeBtn.innerHTML = '<span>🌓</span> B&W Mode';
            }
        });
    }

    // Edit charges directly from invoice viewer
    if (editInvoiceChargesBtn) {
        editInvoiceChargesBtn.addEventListener('click', () => {
            closeInvoiceModal();
            openCreateInvoiceModal(pendingInvoiceVisit, currentPatientProfile);
            if (currentSelectedInvoice) {
                createInvConsultation.value = currentSelectedInvoice.consultationCharge || '';
                createInvXray.value = currentSelectedInvoice.xrayCharge || '';
                createInvPharmacy.value = currentSelectedInvoice.pharmacyCharge || '';
                if (createInvPaymentMode && currentSelectedInvoice.paymentMode) {
                    createInvPaymentMode.value = currentSelectedInvoice.paymentMode;
                }
                calculateCreateInvTotal();
            }
        });
    }

    // Create Invoice Modal Logic
    function openCreateInvoiceModal(visit, profile) {
        createInvConsultation.value = '';
        createInvXray.value = '';
        createInvPharmacy.value = '';
        createInvDisplayTotal.textContent = '0.00';
        createInvoiceModalOverlay.classList.add('active');
    }

    function closeCreateInvoiceModal() {
        createInvoiceModalOverlay.classList.remove('active');
    }

    if (closeCreateInvModalBtn) closeCreateInvModalBtn.addEventListener('click', closeCreateInvoiceModal);
    if (cancelCreateInvBtn) cancelCreateInvBtn.addEventListener('click', closeCreateInvoiceModal);

    function calculateCreateInvTotal() {
        const c = parseFloat(createInvConsultation.value) || 0;
        const x = parseFloat(createInvXray.value) || 0;
        const p = parseFloat(createInvPharmacy.value) || 0;
        const tot = c + x + p;
        createInvDisplayTotal.textContent = tot.toFixed(2);
    }

    createInvConsultation.addEventListener('input', calculateCreateInvTotal);
    createInvXray.addEventListener('input', calculateCreateInvTotal);
    createInvPharmacy.addEventListener('input', calculateCreateInvTotal);

    createInvoiceForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const consultation = parseFloat(createInvConsultation.value) || 0;
        const xray = parseFloat(createInvXray.value) || 0;
        const pharmacy = parseFloat(createInvPharmacy.value) || 0;
        const total = consultation + xray + pharmacy;
        const paymentMode = createInvPaymentMode.value;

        submitCreateInvBtn.disabled = true;
        createInvLoader.style.display = 'block';

        const payload = {
            action: 'generateInvoice',
            fullName: (pendingInvoiceVisit && pendingInvoiceVisit.fullName) || (currentPatientProfile && currentPatientProfile.fullName) || 'Patient',
            phone: (pendingInvoiceVisit && pendingInvoiceVisit.phone) || (currentPatientProfile && currentPatientProfile.phone) || '',
            email: (pendingInvoiceVisit && pendingInvoiceVisit.email) || (currentPatientProfile && currentPatientProfile.email) || '',
            doctorConsulted: (pendingInvoiceVisit && pendingInvoiceVisit.doctorConsulted) || 'Attending Doctor',
            consultationCharge: consultation,
            xrayCharge: xray,
            pharmacyCharge: pharmacy,
            totalAmount: total,
            paymentMode: paymentMode,
            timestamp: new Date().toLocaleString()
        };

        try {
            const res = await fetch(SCRIPT_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                body: JSON.stringify(payload)
            });
            const text = await res.text();
            const result = JSON.parse(text);

            if (result.status === 'success' && result.invoice) {
                closeCreateInvoiceModal();
                currentSelectedInvoice = result.invoice;
                populateAndOpenViewModal(currentSelectedInvoice);

                if (pendingInvoiceVisit) {
                    pendingInvoiceVisit.consultationCharge = consultation;
                    pendingInvoiceVisit.xrayCharge = xray;
                    pendingInvoiceVisit.pharmacyCharge = pharmacy;
                    pendingInvoiceVisit.totalAmount = total;
                    pendingInvoiceVisit.invoiceNo = result.invoice.invoiceNo;
                    pendingInvoiceVisit.driveFileUrl = result.invoice.driveFileUrl;
                }

                cachedInvoicesList.unshift(result.invoice);
                searchBtn.click();
                showToast('Invoice Saved', `Invoice ${result.invoice.invoiceNo} successfully created!`, 'success');
            } else {
                alert(result.message || 'Error generating invoice. Please try again.');
            }
        } catch (err) {
            console.error('Invoice error:', err);
            showToast('Invoice Save Error', 'Failed to connect to Google Apps Script backend.', 'error');
        } finally {
            submitCreateInvBtn.disabled = false;
            createInvLoader.style.display = 'none';
        }
    });

    // Print Invoice Handler
    if (printInvoiceBtn) {
        printInvoiceBtn.addEventListener('click', () => {
            document.body.classList.add('printing-invoice');
            window.print();
            setTimeout(() => {
                document.body.classList.remove('printing-invoice');
            }, 1000);
        });
    }

    // Download Invoice Handler
    if (downloadInvoiceBtn) {
        downloadInvoiceBtn.addEventListener('click', () => {
            if (!currentSelectedInvoice) return;

            const invoiceHtml = generatePrintableHtml(currentSelectedInvoice);
            const blob = new Blob([invoiceHtml], { type: 'text/html;charset=utf-8' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `Invoice_${currentSelectedInvoice.invoiceNo}_${currentSelectedInvoice.fullName.replace(/\s+/g, '_')}.html`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        });
    }

    // Print Patient Records Handler
    if (printBtn) {
        printBtn.addEventListener('click', () => {
            window.print();
        });
    }

    function generatePrintableHtml(inv) {
        const displayAge = inv.age ? (inv.age + ' yrs') : (inv.dob || (currentPatientProfile && (currentPatientProfile.age ? (currentPatientProfile.age + ' yrs') : currentPatientProfile.dob)) || 'N/A');
        const displayAddress = inv.address || inv.email || (currentPatientProfile && (currentPatientProfile.address || currentPatientProfile.email)) || 'N/A';
        const displayOp = inv.opNumber || (currentPatientProfile && currentPatientProfile.opNumber) || 'N/A';
        const logoSrc = (typeof window !== 'undefined' && window.INVOICE_LOGO_BASE64) ? window.INVOICE_LOGO_BASE64 : 'assets/img/logo.png';
        const sealSrc = (typeof window !== 'undefined' && window.INVOICE_SEAL_BASE64) ? window.INVOICE_SEAL_BASE64 : 'assets/img/seal.jpg';
        return `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Invoice - ${inv.invoiceNo}</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; padding: 25px; color: #000; background: #fff; margin: 0; }
        .invoice-box { max-width: 680px; margin: auto; border: 2px solid #000; padding: 24px; border-radius: 6px; }
        .hospital-header { text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 14px; }
        .hospital-logo { max-height: 55px; max-width: 180px; display: block; margin: 0 auto 8px auto; object-fit: contain; }
        .hospital-seal { max-height: 65px; max-width: 130px; display: block; margin: 0 auto 6px auto; object-fit: contain; }
        .hospital-name { font-size: 20px; font-weight: 800; letter-spacing: 0.5px; text-transform: uppercase; margin: 0; color: #000; }
        .hospital-sub { font-size: 12px; font-weight: 600; color: #222; margin-top: 4px; }
        .hospital-contact { font-size: 11px; color: #444; margin-top: 3px; }
        .doc-header { display: flex; justify-content: space-between; border-bottom: 1.5px solid #000; padding-bottom: 8px; margin-bottom: 14px; }
        .title { font-size: 16px; font-weight: bold; color: #000; }
        .sub { font-size: 12px; color: #444; margin-top: 2px; }
        .meta { text-align: right; }
        .meta h2 { margin: 0; font-size: 15px; color: #000; font-weight: bold; }
        .meta p { margin: 2px 0; font-size: 12px; color: #222; }
        .patient { background: #fff; border: 1.5px solid #000; padding: 10px 14px; border-radius: 4px; margin-bottom: 16px; display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 12px; }
        .patient div strong { color: #000; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 18px; border: 1px solid #000; }
        th { background: #f2f2f2; color: #000; padding: 8px 10px; text-align: left; font-size: 12px; font-weight: bold; border: 1px solid #000; }
        td { padding: 8px 10px; border: 1px solid #000; font-size: 12px; color: #000; }
        td.amt { text-align: right; font-weight: 600; }
        th.amt { text-align: right; }
        tr.total td { font-size: 14px; font-weight: bold; color: #000; border-top: 2px solid #000; border-bottom: 3px double #000; background: #fafafa; }
        .signatures { display: flex; justify-content: flex-end; margin-top: 35px; margin-bottom: 15px; padding: 0 10px; }
        .sign-col { text-align: center; width: 220px; font-size: 11px; font-weight: bold; text-transform: uppercase; }
        .sign-line { height: 15px; border-bottom: 1.5px solid #000; margin-bottom: 4px; }
        .footer { text-align: center; font-size: 10.5px; color: #333; margin-top: 15px; border-top: 1px solid #000; padding-top: 8px; font-style: italic; }
        @media print {
            body { padding: 0; }
            .invoice-box { border: none; padding: 0; }
        }
    </style>
</head>
<body onload="window.print()">
    <div class="invoice-box">
        <div class="hospital-header">
            <img src="${logoSrc}" alt="Manjaly Multi Speciality Dental Care" class="hospital-logo">
            <h1 class="hospital-name">MANJALY MULTI SPECIALITY DENTAL CARE</h1>
            <div class="hospital-sub">Valakkavu, above MJ supermarket, Thrissur, Kerala 680751</div>
            <div class="hospital-contact">Phone: +91 6238497517 • Email: manjalymdc@gmail.com</div>
        </div>
        <div class="doc-header">
            <div>
                <div class="title">Clinical Patient Invoice</div>
                <div class="sub">Official Medical Consultation & Services Receipt</div>
            </div>
            <div class="meta">
                <h2>${inv.invoiceNo}</h2>
                <p>Date: ${inv.timestamp}</p>
                <p><strong>PAID (${inv.paymentMode || 'Cash'})</strong></p>
            </div>
        </div>
        <div class="patient">
            <div><strong>Patient Name:</strong> ${inv.fullName}</div>
            <div><strong>Phone:</strong> ${inv.phone || 'N/A'}</div>
            <div><strong>Age:</strong> ${displayAge}</div>
            <div><strong>OP Number:</strong> ${displayOp}</div>
            <div><strong>Doctor Consulted:</strong> ${inv.doctorConsulted}</div>
            <div><strong>Payment Mode:</strong> ${inv.paymentMode || 'Cash'}</div>
            <div style="grid-column: span 2;"><strong>Address of Patient:</strong> ${displayAddress}</div>
        </div>
        <table>
            <thead>
                <tr><th>#</th><th>Description</th><th class="amt">Amount</th></tr>
            </thead>
            <tbody>
                <tr><td>1</td><td>Doctor Consultation Charge</td><td class="amt">${parseFloat(inv.consultationCharge).toFixed(2)}</td></tr>
                <tr><td>2</td><td>X-Ray Examination Charge</td><td class="amt">${parseFloat(inv.xrayCharge).toFixed(2)}</td></tr>
                <tr><td>3</td><td>Pharmacy / Medicines Charge</td><td class="amt">${parseFloat(inv.pharmacyCharge).toFixed(2)}</td></tr>
                <tr class="total"><td colspan="2" style="text-align:right;">Total Amount:</td><td class="amt">${parseFloat(inv.totalAmount).toFixed(2)}</td></tr>
            </tbody>
        </table>
        <div class="signatures">
            <div class="sign-col">
                <img src="${sealSrc}" alt="Authorized Hospital Seal" class="hospital-seal">
                <div class="sign-line"></div>
                Authorized Doctor / Hospital Seal
            </div>
        </div>
        <div class="footer">* Computer generated clinical invoice issued by Manjaly Multi Speciality Dental Care. Valid for all official and claim purposes.</div>
    </div>
</body>
</html>`;
    }

    function showSearchMessage(msg, type) {
        if (!searchMessage) return;
        searchMessage.textContent = msg;
        searchMessage.className = `search-message ${type}`;
        searchMessage.style.display = 'block';
    }

    function formatDate(dateString) {
        if (!dateString) return 'N/A';
        try {
            if (typeof dateString === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(dateString.trim())) {
                const parts = dateString.trim().split('-');
                const d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
            }
            const d = new Date(dateString);
            if (!isNaN(d.getTime())) {
                return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
            }
        } catch(e) {}
        return dateString;
    }

    function escapeHtml(text) {
        if (!text) return '';
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return String(text).replace(/[&<>"']/g, m => map[m]);
    }
});
