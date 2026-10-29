document.addEventListener('DOMContentLoaded', () => {
    // Google Apps Script Web App URL
    const SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

    const patientsCardsContainer = document.getElementById('patientsCardsContainer');
    // Summary Badges
    const totalPatientsBadge = document.getElementById('totalPatientsBadge');
    const totalVisitsBadge = document.getElementById('totalVisitsBadge');
    const totalInvoicesBadge = document.getElementById('totalInvoicesBadge');
    if (totalInvoicesBadge && totalInvoicesBadge.parentElement) {
        totalInvoicesBadge.parentElement.style.display = 'none';
    }
    const patientFilterInput = document.getElementById('patientFilterInput');
    const refreshPatientsBtn = document.getElementById('refreshPatientsBtn');
    const patientsLoader = document.getElementById('patientsLoader');
    const patientsMessage = document.getElementById('patientsMessage');
    const filterPillBtns = document.querySelectorAll('.filter-pill-btn');

    // View Patient Modal Elements
    const viewPatientModalOverlay = document.getElementById('viewPatientModalOverlay');
    const closePatientModalBtn = document.getElementById('closePatientModalBtn');
    const donePatientModalBtn = document.getElementById('donePatientModalBtn');
    const modalPatientAvatar = document.getElementById('modalPatientAvatar');
    const modalPatientName = document.getElementById('modalPatientName');
    const modalPatientPhone = document.getElementById('modalPatientPhone');
    const modalOpVal = document.getElementById('modalOpVal');
    const modalPhoneVal = document.getElementById('modalPhoneVal');
    const modalEmailVal = document.getElementById('modalEmailVal');
    const modalDobVal = document.getElementById('modalDobVal');
    const modalGenderVal = document.getElementById('modalGenderVal');
    const modalDoctorVal = document.getElementById('modalDoctorVal');
    const modalVisitsCountVal = document.getElementById('modalVisitsCountVal');
    const modalMedicalVal = document.getElementById('modalMedicalVal');
    const modalDiseaseVal = document.getElementById('modalDiseaseVal');
    const modalBillingSummary = document.getElementById('modalBillingSummary');
    const modalVisitsTimeline = document.getElementById('modalVisitsTimeline');
    const modalBookAptBtn = document.getElementById('modalBookAptBtn');
    const modalSearchBtn = document.getElementById('modalSearchBtn');
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

    let allPatientsList = [];
    let currentSelectedPatient = null;
    let activeFilter = 'all';

    // Initial Fetch
    fetchRegisteredPatients();

    // Refresh Button Handler
    if (refreshPatientsBtn) {
        refreshPatientsBtn.addEventListener('click', () => {
            fetchRegisteredPatients();
        });
    }

    // Filter Input & Clear Button Handlers
    const patientFilterClearBtn = document.getElementById('patientFilterClearBtn');
    if (patientFilterInput) {
        patientFilterInput.addEventListener('input', () => {
            if (patientFilterClearBtn) {
                patientFilterClearBtn.style.display = patientFilterInput.value.trim() ? 'flex' : 'none';
            }
            renderFilteredPatients();
        });
    }

    if (patientFilterClearBtn && patientFilterInput) {
        patientFilterClearBtn.addEventListener('click', () => {
            patientFilterInput.value = '';
            patientFilterClearBtn.style.display = 'none';
            patientFilterInput.focus();
            renderFilteredPatients();
        });
    }

    // Filter Pills
    const allPillBtns = document.querySelectorAll('.filter-pill-btn, .dir-filter-pill, .patient-dir-pill');
    allPillBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            allPillBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            activeFilter = btn.getAttribute('data-filter') || 'all';
            renderFilteredPatients();
        });
    });

    // Modal Close Handlers
    if (closePatientModalBtn) closePatientModalBtn.addEventListener('click', closePatientModal);
    if (donePatientModalBtn) donePatientModalBtn.addEventListener('click', closePatientModal);

    function closePatientModal() {
        if (viewPatientModalOverlay) viewPatientModalOverlay.classList.remove('active');
    }

    function showPatientsNotice(text, type = 'info') {
        if (!patientsMessage) return;
        patientsMessage.textContent = text;
        patientsMessage.className = 'search-message ' + type;
        patientsMessage.style.display = 'block';
    }

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

    // Fetch Patients
    async function fetchRegisteredPatients() {
        if (patientsLoader) patientsLoader.style.display = 'block';
        if (refreshPatientsBtn) refreshPatientsBtn.disabled = true;
        if (patientsMessage) patientsMessage.style.display = 'none';

        try {
            // First attempt primary getPatients action
            const res = await fetch(`${SCRIPT_URL}?action=getPatients`);
            const text = await res.text();
            let result;
            try {
                result = JSON.parse(text);
            } catch(e) {
                result = null;
            }

            if (result && result.status === 'success' && Array.isArray(result.data)) {
                allPatientsList = result.data;
                updateStatsBadges(allPatientsList, result.totalVisits);
                renderFilteredPatients();
                return;
            }

            // Fallback for older Google Apps Script deployment: Query search endpoint and merge accurately
            const fallbackQueries = ['a', 'e', 'i', 'o', 'u', 's', 'r', '9', '8', '7', '1', '2', '3'];
            const mergedMap = {};
            let fetchedVisitsCount = 0;

            // Execute queries in small concurrent batches for rapid loading
            for (let i = 0; i < fallbackQueries.length; i += 3) {
                const batch = fallbackQueries.slice(i, i + 3);
                await Promise.all(batch.map(async (q) => {
                    try {
                        const fRes = await fetch(`${SCRIPT_URL}?action=search&query=${encodeURIComponent(q)}`);
                        const fJson = await fRes.json();
                        if (fJson && fJson.status === 'success') {
                            const visits = Array.isArray(fJson.data) ? fJson.data : [];
                            const invoices = Array.isArray(fJson.invoices) ? fJson.invoices : [];

                            visits.forEach(v => {
                                const rawName = (v.fullName || v.patientName || '').trim();
                                const rawPhone = (v.phone || '').toString().trim();
                                const rawDob = (v.dob || '').toString().trim();
                                if (!rawName && !rawPhone) return;

                                const digits = rawPhone.replace(/\D/g, '');
                                const cleanName = rawName.toLowerCase().replace(/\s+/g, ' ');
                                const normDob = normalizeDateStr(rawDob);

                                // Rule: A person with same phone number and name, or matching OP, is the SAME PERSON!
                                let existingKey = null;
                                for (const [k, p] of Object.entries(mergedMap)) {
                                    const pName = (p.fullName || '').toLowerCase().replace(/\s+/g, ' ').trim();
                                    const pDigits = (p.phone || '').toString().replace(/\D/g, '');
                                    const vOp = (v.opNumber || '').toLowerCase().trim();
                                    const pOp = (p.opNumber || '').toLowerCase().trim();

                                    const nameMatch = cleanName && pName && (cleanName === pName);
                                    const phoneMatch = digits && pDigits && (digits === pDigits || (digits.length >= 10 && pDigits.length >= 10 && digits.slice(-10) === pDigits.slice(-10)));
                                    const opMatch = vOp && pOp && (vOp === pOp);

                                    if ((nameMatch && phoneMatch) || opMatch) {
                                        existingKey = k;
                                        break;
                                    }
                                }

                                const key = existingKey || (cleanName ? (cleanName + '_' + digits) : (v.opNumber ? ('op_' + v.opNumber) : ('pt_' + fetchedVisitsCount)));

                                let doc = (v.doctorConsulted || '').trim();
                                if (doc.toLowerCase().includes('consulting specialist')) doc = '';

                                // Clean charges: guard against header shift where doctor name appeared in consultationCharge
                                let consult = parseFloat(v.consultationCharge);
                                if (isNaN(consult) || (typeof v.consultationCharge === 'string' && v.consultationCharge.toLowerCase().trim() === doc.toLowerCase().trim())) {
                                    consult = 0;
                                }
                                const xray = parseFloat(v.xrayCharge) || 0;
                                const pharm = parseFloat(v.pharmacyCharge) || 0;
                                const tot = parseFloat(v.totalAmount) || (consult + xray + pharm);

                                fetchedVisitsCount++;

                                if (!mergedMap[key]) {
                                    mergedMap[key] = {
                                        fullName: rawName,
                                        phone: rawPhone,
                                        opNumber: v.opNumber || '',
                                        email: v.email || '',
                                        dob: rawDob || '',
                                        gender: v.gender || 'Not Specified',
                                        doctorConsulted: doc,
                                        medicalHistory: v.medicalHistory || '',
                                        diseaseHistory: v.diseaseHistory || '',
                                        latestVisit: v.timestamp || v.lastVisitDate || '',
                                        visitsCount: 1,
                                        totalBilled: tot,
                                        visits: [v],
                                        invoices: []
                                    };
                                } else {
                                    const exist = mergedMap[key];
                                    if (!exist.opNumber && v.opNumber) exist.opNumber = v.opNumber;
                                    const alreadyHasVisit = exist.visits.some(ev => 
                                        (ev.timestamp && v.timestamp && ev.timestamp === v.timestamp) || 
                                        (ev.invoiceNo && v.invoiceNo && ev.invoiceNo === v.invoiceNo)
                                    );
                                    if (!alreadyHasVisit) {
                                        exist.visitsCount++;
                                        exist.totalBilled += tot;
                                        if (!exist.email && v.email) exist.email = v.email;
                                        if (!exist.dob && rawDob) exist.dob = rawDob;
                                        if (doc && !exist.doctorConsulted) exist.doctorConsulted = doc;
                                        exist.visits.push(v);
                                    }
                                }
                            });

                            invoices.forEach(inv => {
                                const invName = (inv.patientName || '').trim().toLowerCase().replace(/\s+/g, ' ');
                                const digits = (inv.phone || '').replace(/\D/g, '');
                                
                                for (const [k, p] of Object.entries(mergedMap)) {
                                    const pName = (p.fullName || '').toLowerCase().replace(/\s+/g, ' ').trim();
                                    const pDigits = (p.phone || '').toString().replace(/\D/g, '');
                                    if (pName === invName || (digits && pDigits === digits)) {
                                        const hasInv = p.invoices.some(ei => ei.invoiceNo === inv.invoiceNo);
                                        if (!hasInv) p.invoices.push(inv);
                                        break;
                                    }
                                }
                            });
                        }
                    } catch(subErr) {}
                }));
            }

            allPatientsList = Object.values(mergedMap);
            allPatientsList.sort((a, b) => (b.latestVisit || '').localeCompare(a.latestVisit || ''));

            updateStatsBadges(allPatientsList, fetchedVisitsCount);
            renderFilteredPatients();

        } catch (err) {
            console.error('Fetch patients error:', err);
            patientsCardsContainer.innerHTML = `
                <div style="text-align: center; padding: 2.5rem; background: #fee2e2; border-radius: 12px; color: #b91c1c;">
                    <p style="font-weight: 600;">Failed to load patients. Please check your network or Google Apps Script deployment.</p>
                </div>
            `;
        } finally {
            if (patientsLoader) patientsLoader.style.display = 'none';
            if (refreshPatientsBtn) refreshPatientsBtn.disabled = false;
        }
    }

    function updateStatsBadges(patients, totalVisits) {
        if (totalPatientsBadge) totalPatientsBadge.textContent = patients.length;
        
        let visitsTotal = totalVisits || 0;
        if (!totalVisits) {
            visitsTotal = patients.reduce((acc, p) => acc + (p.visitsCount || (p.visits ? p.visits.length : 1)), 0);
        }

        if (totalVisitsBadge) totalVisitsBadge.textContent = visitsTotal;

        // Update Category Pill Counters
        const countAllPill = document.getElementById('countAllPill');
        const countMalePill = document.getElementById('countMalePill');
        const countFemalePill = document.getElementById('countFemalePill');
        const countBilledPill = document.getElementById('countBilledPill');

        if (countAllPill) countAllPill.textContent = patients.length;
        if (countMalePill) countMalePill.textContent = patients.filter(p => (p.gender || '').toLowerCase() === 'male').length;
        if (countFemalePill) countFemalePill.textContent = patients.filter(p => (p.gender || '').toLowerCase() === 'female').length;
        if (countBilledPill) countBilledPill.textContent = patients.filter(p => (parseFloat(p.totalBilled) || 0) > 0 || (p.invoices && p.invoices.length > 0)).length;
    }

    function renderFilteredPatients() {
        const query = (patientFilterInput ? patientFilterInput.value : '').toLowerCase().trim();
        const queryDigits = query.replace(/\D/g, '');

        let filtered = allPatientsList.filter(p => {
            // Text matching & fuzzy phone search
            let matchQuery = !query;
            if (!matchQuery) {
                const pName = (p.fullName || '').toLowerCase();
                const pPhone = (p.phone || '').toString();
                const pDigits = pPhone.replace(/\D/g, '');
                const pEmail = (p.email || '').toLowerCase();
                const pOp = (p.opNumber || '').toLowerCase();
                const pDoctor = (p.doctorConsulted || '').toLowerCase();
                const pMed = (p.medicalHistory || '').toLowerCase();

                matchQuery = pName.includes(query) ||
                             pPhone.includes(query) ||
                             pOp.includes(query) ||
                             pEmail.includes(query) ||
                             pDoctor.includes(query) ||
                             pMed.includes(query);

                if (!matchQuery && queryDigits.length >= 3) {
                    matchQuery = pDigits.includes(queryDigits) || queryDigits.includes(pDigits);
                }
            }

            if (!matchQuery) return false;

            // Pill filter
            if (activeFilter === 'male') return (p.gender || '').toLowerCase() === 'male';
            if (activeFilter === 'female') return (p.gender || '').toLowerCase() === 'female';
            if (activeFilter === 'billed') return (parseFloat(p.totalBilled) || 0) > 0 || (p.invoices && p.invoices.length > 0);

            return true;
        });

        // Update Results Counter
        const directoryResultsCounter = document.getElementById('directoryResultsCounter');
        if (directoryResultsCounter) {
            if (query) {
                directoryResultsCounter.textContent = `Showing ${filtered.length} of ${allPatientsList.length} patients`;
            } else if (activeFilter !== 'all') {
                directoryResultsCounter.textContent = `Showing ${filtered.length} ${activeFilter} patients`;
            } else {
                directoryResultsCounter.textContent = `Total ${allPatientsList.length} patients in directory`;
            }
        }

        if (filtered.length === 0) {
            patientsCardsContainer.innerHTML = `
                <div style="text-align: center; padding: 3.5rem 1.5rem; background: #ffffff; border-radius: 18px; color: #64748b; border: 2px dashed #cbd5e1; margin-top: 1rem;">
                    <div style="width: 60px; height: 60px; border-radius: 50%; background: #f0fdfa; color: #0d9488; font-size: 1.8rem; display: flex; align-items: center; justify-content: center; margin: 0 auto 0.8rem auto;">🔍</div>
                    <h3 style="font-size: 1.2rem; font-weight: 800; color: #0f172a; margin-bottom: 0.35rem;">No Patients Found</h3>
                    <p style="font-size: 0.92rem; max-width: 440px; margin: 0 auto 1.2rem auto;">No registered patients match your search criteria. Try another spelling, phone number, or clear the filter.</p>
                    <button type="button" class="patient-sync-btn" id="resetDirSearchBtn" style="display: inline-flex; margin: 0 auto;">
                        <span>Reset Search</span>
                    </button>
                </div>
            `;
            const resetBtn = document.getElementById('resetDirSearchBtn');
            if (resetBtn) {
                resetBtn.addEventListener('click', () => {
                    if (patientFilterInput) patientFilterInput.value = '';
                    if (patientFilterClearBtn) patientFilterClearBtn.style.display = 'none';
                    activeFilter = 'all';
                    allPillBtns.forEach(b => b.classList.toggle('active', b.getAttribute('data-filter') === 'all'));
                    renderFilteredPatients();
                });
            }
            return;
        }

        patientsCardsContainer.innerHTML = `
            <div class="patients-grid">
                ${filtered.map((patient, idx) => {
                    const initials = getInitials(patient.fullName);
                    const totalBilled = parseFloat(patient.totalBilled) || 0;
                    const visitsCount = patient.visitsCount || (patient.visits ? patient.visits.length : 1);
                    const doctor = cleanDoctor(patient.doctorConsulted);

                    const latestInvNo = (patient.invoices && patient.invoices.length > 0) ? patient.invoices[0].invoiceNo : (patient.visits && patient.visits.length > 0 ? (patient.visits[0].invoiceNo || '') : '');
                    const invRedirectUrl = `search.html?phone=${encodeURIComponent(patient.phone || '')}&name=${encodeURIComponent(patient.fullName || '')}&invoice=${encodeURIComponent(latestInvNo)}&openInvoice=true`;

                    return `
                        <div class="patient-card">
                            <div class="patient-card-header">
                                <div class="patient-avatar">${escapeHtml(initials)}</div>
                                <div class="patient-card-title-box">
                                    <h3 class="patient-name">${escapeHtml(patient.fullName || 'Valued Patient')}</h3>
                                    <div class="patient-sub-info">
                                        <span>📞 <a href="tel:${escapeHtml(patient.phone)}" style="color: #0d9488; font-weight: 600;">${escapeHtml(patient.phone || 'N/A')}</a></span>
                                        ${patient.opNumber ? `<span class="badge-op" style="background:#ccfbf1;color:#0f766e;font-weight:700;padding:2px 8px;border-radius:6px;font-size:0.75rem;font-family:monospace;">${escapeHtml(patient.opNumber)}</span>` : ''}
                                        ${patient.gender ? `<span>• ${escapeHtml(patient.gender)}</span>` : ''}
                                    </div>
                                </div>
                            </div>

                            <div class="patient-meta-grid">
                                <div><strong>Doctor:</strong> ${escapeHtml(doctor || 'Attending Doctor')}</div>
                                <div><strong>Visits:</strong> <span class="badge-visits">${visitsCount} visit${visitsCount > 1 ? 's' : ''}</span></div>
                                ${patient.dob ? `<div><strong>DOB:</strong> ${escapeHtml(formatDate(patient.dob))}</div>` : ''}
                                <div><strong>Billing:</strong> <span class="badge-billed">₹${totalBilled.toFixed(2)}</span></div>
                            </div>

                            ${patient.medicalHistory ? `
                                <div class="patient-note-preview">
                                    <strong>Medical:</strong> ${escapeHtml(patient.medicalHistory)}
                                </div>
                            ` : ''}

                            <div class="patient-card-actions">
                                <button type="button" class="action-btn btn-view-patient" data-patient-idx="${idx}">
                                    <span>👁️</span> View Patient
                                </button>
                                <div class="patient-card-sub-actions">
                                    <a href="appointments.html?name=${encodeURIComponent(patient.fullName || '')}&phone=${encodeURIComponent(patient.phone || '')}" class="mini-btn btn-quick-book" title="Book Appointment">
                                        <span>📅</span> Book
                                    </a>
                                    <a href="${invRedirectUrl}" class="mini-btn btn-quick-search" style="background: #0d9488; color: white; font-weight: 700;" title="Search & Show Hospital Invoice">
                                        <span>🧾</span> Invoice
                                    </a>
                                </div>
                            </div>
                        </div>
                    `;
                }).join('')}
            </div>
        `;

        // Attach View Patient click listeners
        patientsCardsContainer.querySelectorAll('.btn-view-patient').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const idx = parseInt(e.currentTarget.getAttribute('data-patient-idx'), 10);
                const p = filtered[idx];
                if (p) {
                    openPatientModal(p);
                }
            });
        });
    }

    function openPatientModal(patient) {
        currentSelectedPatient = patient;

        modalPatientAvatar.textContent = getInitials(patient.fullName);
        modalPatientName.textContent = patient.fullName || 'Patient Details';
        modalPatientPhone.textContent = `📞 ${patient.phone || 'N/A'}`;

        if (modalOpVal) modalOpVal.textContent = patient.opNumber || 'N/A';
        modalPhoneVal.innerHTML = patient.phone ? `<a href="tel:${escapeHtml(patient.phone)}" style="color: #0d9488; font-weight: 600;">${escapeHtml(patient.phone)}</a>` : 'N/A';
        modalEmailVal.textContent = patient.email || 'None';
        modalDobVal.textContent = formatDate(patient.dob);
        modalGenderVal.textContent = patient.gender || 'Not Specified';
        modalDoctorVal.textContent = cleanDoctor(patient.doctorConsulted) || 'Attending Doctor';
        modalVisitsCountVal.textContent = patient.visitsCount || (patient.visits ? patient.visits.length : 1);
        modalMedicalVal.textContent = patient.medicalHistory || 'None reported';
        modalDiseaseVal.textContent = patient.diseaseHistory || 'None reported';

        // Billing Summary
        const totalBilled = parseFloat(patient.totalBilled) || 0;
        const invoices = Array.isArray(patient.invoices) ? patient.invoices : [];
        const latestInvNo = invoices.length > 0 ? invoices[0].invoiceNo : (patient.visits && patient.visits.length > 0 ? (patient.visits[0].invoiceNo || '') : '');
        const modalInvRedirectUrl = `search.html?phone=${encodeURIComponent(patient.phone || '')}&name=${encodeURIComponent(patient.fullName || '')}&invoice=${encodeURIComponent(latestInvNo)}&openInvoice=true`;

        modalBillingSummary.innerHTML = `
            <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 0.9rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.6rem;">
                <div>
                    <span style="font-size: 0.85rem; color: #64748b; display: block;">Total Amount Billed</span>
                    <strong style="font-size: 1.15rem; color: #0f766e;">₹${totalBilled.toFixed(2)}</strong>
                </div>
                <div>
                    <span style="font-size: 0.85rem; color: #64748b; display: block;">Recorded Invoices</span>
                    <strong style="font-size: 1.15rem; color: #1e3a8a;">${invoices.length}</strong>
                </div>
                <a href="${modalInvRedirectUrl}" class="mini-btn" style="background: #0d9488; color: white; font-weight: 700; padding: 0.5rem 1rem;">
                    <span>🧾</span> View Hospital Invoice
                </a>
            </div>
        `;

        // Visits Timeline
        const visits = Array.isArray(patient.visits) ? patient.visits : [];
        if (visits.length === 0) {
            modalVisitsTimeline.innerHTML = `<p style="font-size: 0.88rem; color: #64748b; font-style: italic;">No detailed visits recorded.</p>`;
        } else {
            modalVisitsTimeline.innerHTML = `
                <div style="display: flex; flex-direction: column; gap: 0.7rem; margin-top: 0.4rem;">
                    ${visits.map(v => {
                        const tot = parseFloat(v.totalAmount) || ((parseFloat(v.consultationCharge) || 0) + (parseFloat(v.xrayCharge) || 0) + (parseFloat(v.pharmacyCharge) || 0));
                        const vInvUrl = `search.html?phone=${encodeURIComponent(patient.phone || '')}&name=${encodeURIComponent(patient.fullName || '')}&invoice=${encodeURIComponent(v.invoiceNo || '')}&openInvoice=true`;
                        return `
                            <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 0.8rem;">
                                <div style="display: flex; justify-content: space-between; font-size: 0.85rem; color: #1e3a8a; font-weight: 600; margin-bottom: 0.2rem;">
                                    <span>📅 ${escapeHtml(v.timestamp || 'Recorded Visit')}</span>
                                    ${tot > 0 ? `<span style="color: #0f766e;">₹${tot.toFixed(2)}</span>` : ''}
                                </div>
                                <div style="font-size: 0.85rem; color: #334155;">
                                    <strong>Doctor:</strong> ${escapeHtml(cleanDoctor(v.doctorConsulted) || 'Attending Doctor')}
                                </div>
                                ${v.medicalHistory ? `<div style="font-size: 0.8rem; color: #64748b; margin-top: 0.2rem;">${escapeHtml(v.medicalHistory)}</div>` : ''}
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 0.5rem; padding-top: 0.4rem; border-top: 1px dashed #e2e8f0;">
                                    <span style="font-size: 0.78rem; color: #64748b;">${v.invoiceNo ? `Inv: <strong>${escapeHtml(v.invoiceNo)}</strong>` : 'Clinical Visit'}</span>
                                    <a href="${vInvUrl}" class="mini-btn" style="background: #0d9488; color: white; padding: 3px 8px; font-size: 0.78rem; text-decoration: none; border-radius: 6px;">
                                        <span>🧾</span> Open Invoice
                                    </a>
                                </div>
                            </div>
                        `;
                    }).join('')}
                </div>
            `;
        }

        // Setup footer action buttons
        if (modalBookAptBtn) {
            modalBookAptBtn.onclick = () => {
                window.location.href = `appointments.html?name=${encodeURIComponent(patient.fullName || '')}&phone=${encodeURIComponent(patient.phone || '')}`;
            };
        }
        if (modalSearchBtn) {
            modalSearchBtn.onclick = () => {
                window.location.href = modalInvRedirectUrl;
            };
        }
        if (modalPrintBtn) {
            modalPrintBtn.onclick = () => {
                window.print();
            };
        }

        viewPatientModalOverlay.classList.add('active');
    }

    // Helper functions
    function getInitials(name) {
        if (!name) return 'PT';
        const parts = name.trim().split(/\s+/);
        if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
        return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
    }

    function cleanDoctor(name) {
        if (!name) return '';
        const trimmed = name.trim();
        if (trimmed.toLowerCase().includes('consulting specialist')) return '';
        return trimmed;
    }

    function formatDate(dateStr) {
        if (!dateStr) return 'N/A';
        try {
            if (/^\d{4}-\d{2}-\d{2}$/.test(dateStr.trim())) {
                const parts = dateStr.trim().split('-');
                const d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
                return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
            }
            const d = new Date(dateStr);
            if (!isNaN(d.getTime())) {
                return d.toLocaleDateString(undefined, { year: 'numeric', month: 'short', day: 'numeric' });
            }
        } catch(e) {}
        return dateStr;
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
