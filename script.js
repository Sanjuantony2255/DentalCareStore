/**
 * Dental Care Clinic & Hospital
 * Patient Registration & Revisit Controller
 */
document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('patientForm');
    const submitBtn = document.getElementById('submitBtn');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoader = document.getElementById('btnLoader');
    const formMessage = document.getElementById('formMessage');
    const toastContainer = document.getElementById('toastContainer');

    // Celebratory Success Banner Elements
    const formSuccessBanner = document.getElementById('formSuccessBanner');
    const successBannerTitle = document.getElementById('successBannerTitle');
    const successBannerSubtitle = document.getElementById('successBannerSubtitle');
    const successDetailsChips = document.getElementById('successDetailsChips');
    const bannerViewInvoiceBtn = document.getElementById('bannerViewInvoiceBtn');
    const bannerNewPatientBtn = document.getElementById('bannerNewPatientBtn');

    // Age and OP Elements
    const ageInput = document.getElementById('age');
    const opNumberInput = document.getElementById('opNumber');
    const addressInput = document.getElementById('address');
    const medicalHistorySelect = document.getElementById('medicalHistorySelect');
    const medicalHistoryInput = document.getElementById('medicalHistory');
    const drugAllergiesInput = document.getElementById('drugAllergies');
    const chiefComplaintInput = document.getElementById('chiefComplaint');
    const diseaseHistoryInput = document.getElementById('diseaseHistory');
    const treatmentInput = document.getElementById('treatmentInput');
    const regQuickTreatments = document.getElementById('regQuickTreatments');
    const regTreatmentDropdown = document.getElementById('regTreatmentDropdown');
    const treatmentSelect = document.getElementById('treatmentSelect');
    const customTreatmentInput = document.getElementById('customTreatment');
    const customTreatmentGroup = document.getElementById('customTreatmentGroup');
    const doctorSelect = document.getElementById('doctorSelect');
    const doctorConsultedInput = document.getElementById('doctorConsulted');
    const doctorConsultedGroup = document.getElementById('doctorConsultedGroup');

    // Billing Inputs
    const consultationInput = document.getElementById('consultationCharge');
    const treatmentChargeInput = document.getElementById('treatmentCharge');
    const xrayInput = document.getElementById('xrayCharge');
    const pharmacyInput = document.getElementById('pharmacyCharge');
    const displayTotal = document.getElementById('displayTotal');
    const totalAmountInput = document.getElementById('totalAmount');
    const paymentModeSelect = document.getElementById('paymentMode');
    const registrationDateInput = document.getElementById('registrationDate');
    const chargeOptionSelect = document.getElementById('chargeOptionSelect');
    const applyChargeOptionBtn = document.getElementById('applyChargeOptionBtn');
    const addCustomChargeBtn = document.getElementById('addCustomChargeBtn');
    const customChargesList = document.getElementById('customChargesList');

    // Default registration date to today (allows previous dates)
    if (registrationDateInput && !registrationDateInput.value) {
        registrationDateInput.value = new Date().toISOString().split('T')[0];
    }

    // Invoice Modal Elements
    const invoiceModalOverlay = document.getElementById('invoiceModalOverlay');
    const closeInvoiceModalBtn = document.getElementById('closeInvoiceModalBtn');
    const doneInvoiceBtn = document.getElementById('doneInvoiceBtn');
    const printInvoiceBtn = document.getElementById('printInvoiceBtn');
    const downloadInvoiceBtn = document.getElementById('downloadInvoiceBtn');
    const shareWhatsappBtn = document.getElementById('shareWhatsappBtn');

    // Invoice Fields
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

    // Current invoice data cache
    let currentInvoiceData = null;

    // Google Apps Script Web App URL
    const SCRIPT_URL = 'https://script.google.com/macros/s/AKfycbyC1zFwfNFa8w-wLJGdEE9ladkNL2rZk-gIfx68CX76upxyQrI1Lar8Tb6BGEvLX4q0/exec';

    // 1. Toast Notification System
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
        setTimeout(dismiss, 5000);
    }

    // Helper to get custom charges list from DOM
    function getCustomChargesData() {
        const list = [];
        if (!customChargesList) return list;
        customChargesList.querySelectorAll('.custom-charge-row').forEach(row => {
            const titleInput = row.querySelector('.charge-title-input');
            const amtInput = row.querySelector('.charge-amt-input');
            const title = (titleInput ? titleInput.value : '').trim();
            const amount = parseFloat(amtInput ? amtInput.value : 0) || 0;
            if (title || amount > 0) {
                list.push({ title: title || 'Custom Charge', amount });
            }
        });
        return list;
    }

    // Dynamic row builder for custom charges (added manually like treatment)
    function addCustomChargeRow(initialTitle = '', initialAmount = '') {
        if (!customChargesList) return;
        const row = document.createElement('div');
        row.className = 'custom-charge-row';
        row.innerHTML = `
            <input type="text" class="charge-title-input" placeholder="Charge Name / Description (e.g. Scaling, Lab Fee)" list="customChargePresetsList" value="${escapeHtml(initialTitle)}">
            <input type="number" class="charge-amt-input" min="0" step="any" placeholder="Amount (₹)" value="${initialAmount}">
            <button type="button" class="btn-remove-charge" title="Remove Charge">&times;</button>
        `;
        row.querySelector('.charge-title-input').addEventListener('input', calculateTotal);
        row.querySelector('.charge-amt-input').addEventListener('input', calculateTotal);
        row.querySelector('.btn-remove-charge').addEventListener('click', () => {
            row.remove();
            calculateTotal();
        });
        customChargesList.appendChild(row);
        const titleInput = row.querySelector('.charge-title-input');
        if (!initialTitle && titleInput) titleInput.focus();
        calculateTotal();
    }

    // 2. Real-time Calculation of Billing Total
    function calculateTotal() {
        const consultation = parseFloat(consultationInput ? consultationInput.value : 0) || 0;
        const treatment = parseFloat(treatmentChargeInput ? treatmentChargeInput.value : 0) || 0;
        const xray = parseFloat(xrayInput ? xrayInput.value : 0) || 0;
        const pharmacy = parseFloat(pharmacyInput ? pharmacyInput.value : 0) || 0;
        
        let customTotal = 0;
        if (customChargesList) {
            customChargesList.querySelectorAll('.custom-charge-row').forEach(row => {
                const amtInput = row.querySelector('.charge-amt-input');
                if (amtInput) {
                    customTotal += (parseFloat(amtInput.value) || 0);
                }
            });
        }

        const total = consultation + treatment + xray + pharmacy + customTotal;

        if (displayTotal) displayTotal.textContent = total.toFixed(2);
        if (totalAmountInput) totalAmountInput.value = total.toFixed(2);
    }

    if (consultationInput) consultationInput.addEventListener('input', calculateTotal);
    if (treatmentChargeInput) treatmentChargeInput.addEventListener('input', calculateTotal);
    if (xrayInput) xrayInput.addEventListener('input', calculateTotal);
    if (pharmacyInput) pharmacyInput.addEventListener('input', calculateTotal);

    if (addCustomChargeBtn) {
        addCustomChargeBtn.addEventListener('click', () => {
            addCustomChargeRow('', '');
        });
    }

    // Standard clinic suggested fees for treatments & procedures
    const TREATMENT_SUGGESTED_FEES = {
        'POST & CORE': 1500,
        'CROWN METAL': 1500,
        'CROWN PFM': 3000,
        'CROWN PFZ': 5500,
        'EMAX CROWN, VENEER, INLAY': 7500,
        'CROWN REMOVAL': 500,
        'ACRYLIC PARTIAL DENTURE': 2000,
        'FLEXIBLE PARTIAL DENTURE': 7000,
        'COMPLETE DENTURE': 15000,
        'FLEXIBLE': 7500,
        'BPS': 25000,
        'SS CROWNS': 1800,
        'SCALING': 1000,
        'GINGIVECTOMY': 1500,
        'SUBGINGIVAL SCALING/ CURETTAGE': 1500,
        'GRAFT': 5000,
        'DEPIGMENTATION': 3000,
        'PERIODONTAL FLAP': 4000,
        'SPLINTING': 1500,
        'LASER': 2000,
        'PULPOTOMY/ PULPECTOMY': 1500,
        'PIT & FISSURE SEALANTS': 600,
        'FLUORIDE APPPLICATIONS': 800,
        'SPACE MAINTAINERS': 2500,
        'PREFORMED ZIRCONIA': 3500,
        'BLEACHING': 5000,
        'DENTAL IMPLANTS': 25000,
        'REGISTRATION': 100,
        'CONSULTATION': 300,
        'SPECIALIST CONSULTATION': 500,
        'DENTAL RADIOGRAPHS': 250,
        'GLASS IONOMER': 600,
        'AMALGAM': 600,
        'COMPOSITE': 800,
        'RCT': 2500,
        'RE RCT': 3500,
        'MICROSCOPE RCT': 4500,
        'APICECTOMY': 3500,
        'MTA': 1200,
        'DECIDUOUS TOOTH EXTRACTION': 300,
        'NORMAL EXTRACTION': 500,
        'DIFFICULT EXTRACTION': 1500,
        '3RD MOLAR': 3500,
        'CANINE IMPACTION': 4000,
        'INCISION AND DRAINAGE': 800,
        'VESTIBULOPLASTY': 3000,
        'ALVEOLOPLASTY': 2000,
        'OPERCULECTOMY': 1000,
        'FIXED ORTHODONTICS PREADJUSTED': 25000,
        'FIXED ORTHODONTICS PREADJUSTED- TOOTH COLORED': 30000,
        'FIXED- SELF LIGATING': 40000,
        'HAWLEYS APPLIANCE- ACTIVE': 3500,
        'RETENTION APPLIANCE- PASSIVE': 2500,
        'FIXED LINGUAL RETAINERS': 3000,
        'VACCUFORM RETAINERS-': 2500,
        'ORAL SCREEN': 2000,
        'MYO FUNCTIONAL FIXED': 8000,
        'MYOFUNCTIONAL REMOVABLE': 6000,
        'CLEAR ALIGNERS': 35000
    };

    // Charge dropdown handler: dropdown only contains treatment name, that charge in another option (treatmentChargeInput)
    if (chargeOptionSelect) {
        function applyTreatmentChargeOption(treatName) {
            if (!treatName) return;
            if (treatmentInput) treatmentInput.value = treatName;
            if (treatmentSelect) treatmentSelect.value = treatName;
            if (customTreatmentInput) customTreatmentInput.value = treatName;

            const suggestedFee = TREATMENT_SUGGESTED_FEES[treatName];
            if (suggestedFee !== undefined && treatmentChargeInput) {
                treatmentChargeInput.value = suggestedFee;
            }
            if (treatmentChargeInput) {
                treatmentChargeInput.focus();
            }
            calculateTotal();
            showToast('Treatment Selected', `${treatName} - set or review charge in Treatment Charge option`, 'info');
        }

        chargeOptionSelect.addEventListener('change', () => {
            const treatName = chargeOptionSelect.value;
            if (treatName) {
                applyTreatmentChargeOption(treatName);
            }
        });

        if (applyChargeOptionBtn) {
            applyChargeOptionBtn.addEventListener('click', () => {
                const treatName = chargeOptionSelect.value;
                if (treatName) {
                    applyTreatmentChargeOption(treatName);
                } else {
                    showToast('Select Treatment', 'Please choose a treatment name from the dropdown', 'warning');
                }
            });
        }
    }

    // 3. Quick Preset Charge Chips
    document.querySelectorAll('.preset-chip').forEach(btn => {
        btn.addEventListener('click', () => {
            const type = btn.getAttribute('data-type');
            const amt = parseFloat(btn.getAttribute('data-amt')) || 0;
            const action = btn.getAttribute('data-action');

            if (action === 'clear') {
                if (consultationInput) consultationInput.value = '';
                if (treatmentChargeInput) treatmentChargeInput.value = '';
                if (xrayInput) xrayInput.value = '';
                if (pharmacyInput) pharmacyInput.value = '';
                if (customChargesList) customChargesList.innerHTML = '';
            } else if (type === 'consultation' && consultationInput) {
                consultationInput.value = amt;
            } else if (type === 'xray' && xrayInput) {
                xrayInput.value = amt;
            } else if (type === 'pharmacy' && pharmacyInput) {
                pharmacyInput.value = amt;
            }
            calculateTotal();
        });
    });

    // 4. Medical History, Treatment & Doctor Select Handlers
    if (medicalHistorySelect && medicalHistoryInput) {
        medicalHistorySelect.addEventListener('change', () => {
            const sel = medicalHistorySelect.value;
            if (sel === 'Other') {
                medicalHistoryInput.value = '';
                medicalHistoryInput.placeholder = 'Please specify medical condition...';
                medicalHistoryInput.focus();
            } else {
                medicalHistoryInput.value = sel;
            }
        });
    }

    // All clinic dental treatments (matching app)
    const ALL_CLINIC_TREATMENTS = [
        'SELECT ANY OPTION / OTHER',
        'GENERAL CONSULTATION / CHECKUP',
        'POST & CORE', 'CROWN METAL', 'CROWN PFM', 'CROWN PFZ', 'EMAX CROWN, VENEER, INLAY',
        'CROWN REMOVAL', 'ACRYLIC PARTIAL DENTURE', 'FLEXIBLE PARTIAL DENTURE', 'COMPLETE DENTURE',
        'FLEXIBLE', 'BPS', 'SS CROWNS', 'SCALING', 'GINGIVECTOMY', 'SUBGINGIVAL SCALING/ CURETTAGE',
        'GRAFT', 'DEPIGMENTATION', 'PERIODONTAL FLAP', 'SPLINTING', 'LASER', 'PULPOTOMY/ PULPECTOMY',
        'PIT & FISSURE SEALANTS', 'FLUORIDE APPPLICATIONS', 'SPACE MAINTAINERS', 'PREFORMED ZIRCONIA',
        'BLEACHING', 'DENTAL IMPLANTS', 'REGISTRATION', 'CONSULTATION', 'SPECIALIST CONSULTATION',
        'DENTAL RADIOGRAPHS', 'GLASS IONOMER', 'AMALGAM', 'COMPOSITE', 'RCT', 'RE RCT',
        'MICROSCOPE RCT', 'APICECTOMY', 'MTA', 'DECIDUOUS TOOTH EXTRACTION', 'NORMAL EXTRACTION',
        'DIFFICULT EXTRACTION', '3RD MOLAR', 'CANINE IMPACTION', 'INCISION AND DRAINAGE',
        'VESTIBULOPLASTY', 'ALVEOLOPLASTY', 'OPERCULECTOMY', 'FIXED ORTHODONTICS PREADJUSTED',
        'FIXED ORTHODONTICS PREADJUSTED- TOOTH COLORED', 'FIXED- SELF LIGATING',
        'HAWLEYS APPLIANCE- ACTIVE', 'RETENTION APPLIANCE- PASSIVE', 'FIXED LINGUAL RETAINERS',
        'VACCUFORM RETAINERS-', 'ORAL SCREEN', 'MYO FUNCTIONAL FIXED', 'MYOFUNCTIONAL REMOVABLE',
        'CLEAR ALIGNERS'
    ];

    if (treatmentInput) {
        function setTreatmentValue(val) {
            treatmentInput.value = val;
            if (treatmentSelect) treatmentSelect.value = val;
            if (customTreatmentInput) customTreatmentInput.value = val;
            if (regQuickTreatments) {
                regQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => {
                    c.classList.toggle('active', c.getAttribute('data-treatment') === val);
                });
            }
            if (regTreatmentDropdown) regTreatmentDropdown.style.display = 'none';
        }

        if (regQuickTreatments) {
            regQuickTreatments.querySelectorAll('.treatment-chip').forEach(chip => {
                chip.addEventListener('click', (e) => {
                    e.preventDefault();
                    setTreatmentValue(chip.getAttribute('data-treatment'));
                    treatmentInput.focus();
                });
            });
        }

        function filterTreatments(query) {
            if (!regTreatmentDropdown) return;
            const q = (query || '').trim().toLowerCase();
            const matches = ALL_CLINIC_TREATMENTS.filter(t => !q || t.toLowerCase().includes(q));

            let html = '';

            // Allow selecting typed custom text as any option
            if (q.length > 0) {
                html += `<div class="treatment-suggest-item custom-option" data-value="${escapeHtml(query.trim())}">
                    <span>✨ Use "<strong>${escapeHtml(query.trim())}</strong>" (Select Any Option)</span>
                    <span style="font-size:0.75rem;color:#0d9488;font-weight:700;">Select</span>
                </div>`;
            }

            if (matches.length > 0) {
                html += matches.map(t => {
                    let display = t;
                    if (q) {
                        const regex = new RegExp(`(${q.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&')})`, 'gi');
                        display = t.replace(regex, '<mark>$1</mark>');
                    }
                    return `<div class="treatment-suggest-item" data-value="${t}"><span>${display}</span><span style="font-size:0.7rem;color:#0d9488;opacity:0.8;">Select</span></div>`;
                }).join('');
            }

            // Always provide option to choose any custom option
            html += `<div class="treatment-suggest-item" data-value="SELECT ANY OPTION / OTHER">
                <span>➕ Select Any Option / Other Treatment...</span>
                <span style="font-size:0.72rem;color:#0d9488;font-weight:700;">Select</span>
            </div>`;

            regTreatmentDropdown.innerHTML = html;
            regTreatmentDropdown.style.display = 'block';

            regTreatmentDropdown.querySelectorAll('.treatment-suggest-item').forEach(item => {
                item.addEventListener('click', (e) => {
                    e.stopPropagation();
                    setTreatmentValue(item.getAttribute('data-value'));
                });
            });
        }

        treatmentInput.addEventListener('focus', () => {
            filterTreatments(treatmentInput.value);
        });

        treatmentInput.addEventListener('input', () => {
            filterTreatments(treatmentInput.value);
            if (treatmentSelect) treatmentSelect.value = treatmentInput.value;
            if (customTreatmentInput) customTreatmentInput.value = treatmentInput.value;
            if (regQuickTreatments) {
                regQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => {
                    c.classList.toggle('active', c.getAttribute('data-treatment') === treatmentInput.value.trim());
                });
            }
        });

        document.addEventListener('click', (e) => {
            if (regTreatmentDropdown && !treatmentInput.contains(e.target) && !regTreatmentDropdown.contains(e.target)) {
                regTreatmentDropdown.style.display = 'none';
            }
        });
    }

    if (doctorSelect && doctorConsultedInput) {
        doctorSelect.addEventListener('change', () => {
            const val = doctorSelect.value;
            if (val === 'Other') {
                if (doctorConsultedGroup) doctorConsultedGroup.style.display = 'flex';
                doctorConsultedInput.value = '';
                doctorConsultedInput.placeholder = 'Type doctor name manually...';
                doctorConsultedInput.focus();
            } else {
                if (doctorConsultedGroup) doctorConsultedGroup.style.display = 'none';
                doctorConsultedInput.value = val;
            }
        });
    }

    // 5. LocalStorage Cache for Fast Lookup & Offline Resilience
    function cachePatientLocally(patientRecord, invoiceRecord) {
        try {
            const cacheKey = 'dental_cached_patients';
            const raw = localStorage.getItem(cacheKey);
            const cachedList = raw ? JSON.parse(raw) : [];

            const pPhoneDigits = (patientRecord.phone || '').toString().replace(/\D/g, '');
            const pName = (patientRecord.fullName || '').toString().trim().toLowerCase().replace(/\s+/g, ' ');

            const existingIdx = cachedList.findIndex(p => {
                const cDigits = (p.phone || '').toString().replace(/\D/g, '');
                const cName = (p.fullName || '').toString().trim().toLowerCase().replace(/\s+/g, ' ');
                const phoneMatch = pPhoneDigits && cDigits && (pPhoneDigits === cDigits || (pPhoneDigits.length >= 10 && cDigits.length >= 10 && pPhoneDigits.slice(-10) === cDigits.slice(-10)));
                const nameMatch = pName && cName && pName === cName;
                return phoneMatch && nameMatch;
            });

            if (existingIdx !== -1) {
                const existing = cachedList[existingIdx];
                cachedList[existingIdx] = {
                    ...existing,
                    ...patientRecord,
                    opNumber: patientRecord.opNumber || existing.opNumber || '',
                    visits: [patientRecord, ...(existing.visits || [])],
                    invoices: invoiceRecord ? [invoiceRecord, ...(existing.invoices || [])] : (existing.invoices || [])
                };
            } else {
                cachedList.unshift({
                    ...patientRecord,
                    visits: [patientRecord],
                    invoices: invoiceRecord ? [invoiceRecord] : []
                });
            }

            // Keep most recent 50 patients cached
            localStorage.setItem(cacheKey, JSON.stringify(cachedList.slice(0, 50)));

            if (invoiceRecord) {
                try {
                    const rawInvs = localStorage.getItem('dental_cached_invoices');
                    const invList = rawInvs ? JSON.parse(rawInvs) : [];
                    const invIdx = invList.findIndex(i => (i.invoiceNo || i.id) === (invoiceRecord.invoiceNo || invoiceRecord.id));
                    if (invIdx !== -1) {
                        invList[invIdx] = { ...invList[invIdx], ...invoiceRecord };
                    } else {
                        invList.unshift(invoiceRecord);
                    }
                    localStorage.setItem('dental_cached_invoices', JSON.stringify(invList.slice(0, 100)));
                } catch(e) {}
            }
        } catch(err) {
            console.warn('Local cache error:', err);
        }
    }

    // Live Auto-Lookup: Returning person with same phone & name gets already registered same OP number
    const fullNameInput = document.getElementById('fullName');
    const phoneInput = document.getElementById('phone');
    const genderSelect = document.getElementById('gender');
    const alreadyRegisteredAlert = document.getElementById('alreadyRegisteredAlert');
    const suggestedOpBadge = document.getElementById('suggestedOpBadge');
    let isOpLookupInProgress = false;

    function setAlreadyRegisteredValidation(opNo) {
        if (opNumberInput && opNo) {
            opNumberInput.value = opNo;
            opNumberInput.dataset.autoFilled = 'true';
        }
        if (suggestedOpBadge && opNo) {
            suggestedOpBadge.textContent = opNo;
        }
        if (alreadyRegisteredAlert && opNo) {
            alreadyRegisteredAlert.style.display = 'flex';
        }
    }

    function clearAlreadyRegisteredValidation() {
        if (alreadyRegisteredAlert) {
            alreadyRegisteredAlert.style.display = 'none';
        }
        if (opNumberInput && opNumberInput.dataset.autoFilled === 'true') {
            opNumberInput.value = '';
            delete opNumberInput.dataset.autoFilled;
        }
    }

    async function checkAndFillExistingOpNumber() {
        if (!fullNameInput || !phoneInput || !opNumberInput) return;
        const nameVal = fullNameInput.value.trim().toLowerCase().replace(/\s+/g, ' ');
        const phoneVal = phoneInput.value.trim();
        const phoneDigits = phoneVal.replace(/\D/g, '');

        if (nameVal.length < 2 || phoneDigits.length < 10) {
            clearAlreadyRegisteredValidation();
            return;
        }

        const matchPatient = (list) => {
            if (!Array.isArray(list)) return null;
            return list.find(p => {
                const cDigits = (p.phone || '').toString().replace(/\D/g, '');
                const cName = (p.fullName || p.patientName || p.name || '').toString().trim().toLowerCase().replace(/\s+/g, ' ');
                const phoneMatch = cDigits && (cDigits === phoneDigits || (cDigits.length >= 10 && phoneDigits.length >= 10 && cDigits.slice(-10) === phoneDigits.slice(-10)));
                const nameMatch = cName === nameVal;
                return phoneMatch && nameMatch && (p.opNumber);
            });
        };

        // 1. Check local cache
        try {
            const raw = localStorage.getItem('dental_cached_patients');
            if (raw) {
                const list = JSON.parse(raw);
                const match = matchPatient(list);
                if (match && match.opNumber) {
                    setAlreadyRegisteredValidation(match.opNumber);
                    if (addressInput && !addressInput.value && (match.address || match.email)) addressInput.value = match.address || match.email;
                    if (ageInput && !ageInput.value && match.age) ageInput.value = match.age;
                    if (genderSelect && (!genderSelect.value || genderSelect.value === '') && match.gender) genderSelect.value = match.gender;
                    showToast('Already Registered Patient', `Recognized patient! Preserving OP: ${match.opNumber}`, 'info');
                    return;
                }
            }
        } catch (e) {}

        // 2. Query Google Sheet backend / Search endpoint
        if (isOpLookupInProgress) return;
        isOpLookupInProgress = true;
        try {
            const res = await fetch(`${SCRIPT_URL}?action=search&query=${encodeURIComponent(phoneDigits)}`);
            const json = await res.json();
            if (json && json.status === 'success' && Array.isArray(json.data) && json.data.length > 0) {
                const match = matchPatient(json.data);
                if (match && match.opNumber) {
                    setAlreadyRegisteredValidation(match.opNumber);
                    if (addressInput && !addressInput.value && (match.address || match.email)) addressInput.value = match.address || match.email;
                    if (ageInput && !ageInput.value && (match.age || match.dob)) ageInput.value = match.age || (match.dob ? match.dob.replace(/[^0-9]/g, '') : '');
                    if (genderSelect && (!genderSelect.value || genderSelect.value === '') && match.gender) genderSelect.value = match.gender;
                    showToast('Already Registered Patient', `Recognized patient! Preserving OP: ${match.opNumber}`, 'info');

                    // Cache for fast immediate recall
                    try {
                        const raw = localStorage.getItem('dental_cached_patients');
                        const list = raw ? JSON.parse(raw) : [];
                        list.unshift(match);
                        localStorage.setItem('dental_cached_patients', JSON.stringify(list.slice(0, 50)));
                    } catch (err) {}
                    return;
                }
            }
        } catch (e) {
            console.warn('OP lookup error:', e);
        } finally {
            isOpLookupInProgress = false;
        }

        clearAlreadyRegisteredValidation();
    }

    if (fullNameInput) {
        fullNameInput.addEventListener('input', () => {
            if (phoneInput && phoneInput.value.replace(/\D/g, '').length >= 10 && fullNameInput.value.trim().length >= 2) {
                checkAndFillExistingOpNumber();
            } else {
                clearAlreadyRegisteredValidation();
            }
        });
        fullNameInput.addEventListener('blur', checkAndFillExistingOpNumber);
    }
    if (phoneInput) {
        phoneInput.addEventListener('input', () => {
            if (phoneInput.value.replace(/\D/g, '').length >= 10 && fullNameInput && fullNameInput.value.trim().length >= 2) {
                checkAndFillExistingOpNumber();
            } else {
                clearAlreadyRegisteredValidation();
            }
        });
        phoneInput.addEventListener('blur', checkAndFillExistingOpNumber);
    }

    // 6. In-Page Celebratory Success Banner Handler
    function showSuccessBanner(patientData, invData) {
        if (!formSuccessBanner) return;

        if (successBannerTitle) {
            successBannerTitle.textContent = `Patient ${patientData.fullName} Registered Successfully!`;
        }
        if (successBannerSubtitle) {
            successBannerSubtitle.textContent = `Official clinical record created on ${patientData.timestamp} and stored in Google Sheets.`;
        }

        if (successDetailsChips) {
            successDetailsChips.innerHTML = `
                <div class="success-chip"><strong>Patient:</strong> ${escapeHtml(patientData.fullName)}</div>
                <div class="success-chip"><strong>Phone:</strong> ${escapeHtml(patientData.phone)}</div>
                <div class="success-chip"><strong>Invoice No:</strong> ${escapeHtml(invData.invoiceNo)}</div>
                <div class="success-chip"><strong>Doctor:</strong> ${escapeHtml(patientData.doctorConsulted || 'Attending Doctor')}</div>
                <div class="success-chip"><strong>Total Amount:</strong> ₹${parseFloat(patientData.totalAmount || 0).toFixed(2)} (${escapeHtml(patientData.paymentMode || 'Cash')})</div>
            `;
        }

        formSuccessBanner.classList.add('active');
        formSuccessBanner.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }

    if (bannerViewInvoiceBtn) {
        bannerViewInvoiceBtn.addEventListener('click', () => {
            if (currentInvoiceData) openInvoiceModal(currentInvoiceData);
        });
    }

    if (bannerNewPatientBtn) {
        bannerNewPatientBtn.addEventListener('click', () => {
            form.reset();
            calculateTotal();
            if (medicalHistorySelect) medicalHistorySelect.value = '';
            if (medicalHistoryInput) medicalHistoryInput.value = '';
            if (drugAllergiesInput) drugAllergiesInput.value = '';
            if (chiefComplaintInput) chiefComplaintInput.value = '';
            if (diseaseHistoryInput) diseaseHistoryInput.value = '';
            if (treatmentInput) treatmentInput.value = '';
            if (regQuickTreatments) regQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => c.classList.remove('active'));
            if (treatmentSelect) treatmentSelect.value = '';
            if (customTreatmentInput) customTreatmentInput.value = '';
            if (customTreatmentGroup) customTreatmentGroup.style.display = 'none';
            if (registrationDateInput) registrationDateInput.value = new Date().toISOString().split('T')[0];
            formSuccessBanner.classList.remove('active');
            const nameInput = document.getElementById('fullName');
            if (nameInput) nameInput.focus();
        });
    }

    // 7. Form Submission Handler
    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        // Calculate latest charges
        calculateTotal();

        // Loading state
        submitBtn.disabled = true;
        btnText.style.display = 'none';
        btnLoader.style.display = 'block';
        if (formMessage) formMessage.style.display = 'none';

        // Gather data
        const formData = new FormData(form);
        const data = Object.fromEntries(formData.entries());
        data.action = 'patientRegistration';

        const now = new Date();
        const pad = (n) => ('0' + n).slice(-2);
        const timePart = `${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
        const selectedDate = (data.registrationDate || (registrationDateInput ? registrationDateInput.value : '')).trim();
        if (selectedDate) {
            data.timestamp = `${selectedDate} ${timePart}`;
            data.date = selectedDate;
            data.registrationDate = selectedDate;
        } else {
            data.timestamp = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${timePart}`;
            data.date = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
        }

        // Address & Email mapping
        data.address = (data.address || '').trim();
        data.email = data.address || data.email || '';

        // Age & DOB mapping
        data.age = (data.age || '').toString().trim();
        if (data.age) {
            data.dob = `${data.age} yrs`;
        }

        // When clicking Submit Registration / Revisit, consider person with same phone & name as the same patient and give already registered OP number
        const rawName = (data.fullName || (fullNameInput ? fullNameInput.value : '') || '').trim().toLowerCase().replace(/\s+/g, ' ');
        const rawPhoneDigits = (data.phone || (phoneInput ? phoneInput.value : '') || '').replace(/\D/g, '');
        let existingMatchOp = null;

        // 1. If opNumberInput already contains an OP number, preserve it (any custom or generated OP format)
        if (opNumberInput && opNumberInput.value && opNumberInput.value.trim().length > 0) {
            existingMatchOp = opNumberInput.value.trim();
        }

        // 2. If not yet determined, match against local cache by phone and exact full name
        if (!existingMatchOp && rawName.length >= 2 && rawPhoneDigits.length >= 10) {
            try {
                const rawCached = localStorage.getItem('dental_cached_patients');
                if (rawCached) {
                    const list = JSON.parse(rawCached);
                    const found = list.find(p => {
                        const cDigits = (p.phone || '').toString().replace(/\D/g, '');
                        const cName = (p.fullName || p.patientName || p.name || '').toString().trim().toLowerCase().replace(/\s+/g, ' ');
                        const phoneMatch = cDigits && (cDigits === rawPhoneDigits || (cDigits.length >= 10 && rawPhoneDigits.length >= 10 && cDigits.slice(-10) === rawPhoneDigits.slice(-10)));
                        const nameMatch = cName === rawName;
                        return phoneMatch && nameMatch && p.opNumber;
                    });
                    if (found && found.opNumber) {
                        existingMatchOp = found.opNumber;
                    }
                }
            } catch (e) {}
        }

        if (existingMatchOp) {
            data.opNumber = existingMatchOp;
            if (opNumberInput) opNumberInput.value = existingMatchOp;
        } else {
            data.opNumber = (data.opNumber || (opNumberInput ? opNumberInput.value : '') || '').trim();
            if (!data.opNumber) {
                const randomCode = Math.floor(1000 + Math.random() * 9000);
                const prefix = `${now.getFullYear().toString().slice(-2)}${pad(now.getMonth() + 1)}`;
                data.opNumber = `OP-${prefix}-${randomCode}`;
                if (opNumberInput) opNumberInput.value = data.opNumber;
            }
        }

        // Medical History & Drug Allergies mapping (remove dummy placeholder values like 'None')
        const medSelected = medicalHistorySelect ? medicalHistorySelect.value : '';
        const medInputVal = (data.medicalHistory || '').trim();
        data.medicalHistory = medInputVal && medInputVal !== 'None' ? medInputVal : (medSelected && medSelected !== 'None' ? medSelected : '');
        
        data.drugAllergies = (data.drugAllergies || '').trim();
        if (data.drugAllergies === 'None') data.drugAllergies = '';

        // Chief Complaint & Treatment mapping
        const complaintVal = (data.chiefComplaint || (chiefComplaintInput ? chiefComplaintInput.value : '') || data.diseaseHistory || '').trim();
        const selectedTreatment = (treatmentInput && treatmentInput.value.trim())
            ? treatmentInput.value.trim()
            : ((treatmentSelect && treatmentSelect.value && treatmentSelect.value !== 'Other')
                ? treatmentSelect.value.trim()
                : (data.customTreatment || (customTreatmentInput ? customTreatmentInput.value : '') || '').trim());
        
        data.chiefComplaint = complaintVal;
        data.treatment = selectedTreatment;
        if (complaintVal && selectedTreatment) {
            data.diseaseHistory = `${complaintVal} - ${selectedTreatment}`;
        } else {
            data.diseaseHistory = complaintVal || selectedTreatment || '';
        }

        // Ensure numeric charges
        data.consultationCharge = parseFloat(data.consultationCharge) || 0;
        data.treatmentCharge = parseFloat(treatmentChargeInput ? treatmentChargeInput.value : data.treatmentCharge) || 0;
        data.xrayCharge = parseFloat(data.xrayCharge) || 0;
        data.pharmacyCharge = parseFloat(data.pharmacyCharge) || 0;
        data.customCharges = getCustomChargesData();
        const customTotal = data.customCharges.reduce((sum, item) => sum + (parseFloat(item.amount) || 0), 0);
        const calcTotal = data.consultationCharge + data.treatmentCharge + data.xrayCharge + data.pharmacyCharge + customTotal;
        data.totalAmount = parseFloat(data.totalAmount) || calcTotal;

        // Clean doctor name
        let doc = (data.doctorConsulted || '').trim();
        if (!doc && doctorSelect && doctorSelect.value && doctorSelect.value !== 'Other') {
            doc = doctorSelect.value;
        }
        if (doc.toLowerCase().includes('consulting specialist')) doc = '';
        data.doctorConsulted = doc || 'Dr. Jeswin Jose BDS';

        try {
            // Optional non-blocking pre-check for returning patient
            try {
                const searchRes = await fetch(`${SCRIPT_URL}?action=search&query=${encodeURIComponent(data.phone)}`);
                const searchJson = await searchRes.json();
                if (searchJson.status === 'success' && Array.isArray(searchJson.data) && searchJson.data.length > 0) {
                    console.log('Existing patient record found. Adding new revisit & billing record.');
                }
            } catch (searchErr) {
                console.warn('Pre-check notice:', searchErr);
            }

            // POST to Google Apps Script
            const response = await fetch(SCRIPT_URL, {
                method: 'POST',
                headers: {
                    'Content-Type': 'text/plain;charset=utf-8',
                },
                body: JSON.stringify(data),
            });

            const textResponse = await response.text();
            let result;
            try {
                result = JSON.parse(textResponse);
            } catch (parseError) {
                if (textResponse.includes('accounts.google.com') || textResponse.includes('ServiceLogin') || textResponse.includes('Google Drive')) {
                    showMessage('Google Authorization Error: In Google Apps Script, ensure Web App deployment has "Who has access" set to "Anyone".', 'error');
                    showToast('Google Authorization Error', 'Apps Script Web App access must be set to "Anyone"', 'error');
                    return;
                }
                throw new Error('Server returned unexpected format: ' + textResponse.substring(0, 100));
            }

            if (result.status === 'success') {
                const returnedInv = result.invoice || {};
                const invDisplayDate = data.date || (data.timestamp ? data.timestamp.split(' ')[0] : '') || returnedInv.timestamp || data.timestamp;
                currentInvoiceData = {
                    invoiceNo: returnedInv.invoiceNo || ('INV-' + Date.now().toString().slice(-6)),
                    timestamp: invDisplayDate,
                    date: data.date || invDisplayDate,
                    fullName: data.fullName || 'Patient',
                    phone: data.phone || '',
                    address: data.address || '',
                    email: data.address || '',
                    age: data.age || '',
                    dob: data.dob || (data.age ? (data.age + ' yrs') : ''),
                    opNumber: returnedInv.opNumber || data.opNumber || '',
                    doctorConsulted: data.doctorConsulted || 'Attending Doctor',
                    treatment: data.treatment || data.diseaseHistory || '',
                    chiefComplaint: data.chiefComplaint || '',
                    consultationCharge: data.consultationCharge,
                    treatmentCharge: data.treatmentCharge || 0,
                    xrayCharge: data.xrayCharge,
                    pharmacyCharge: data.pharmacyCharge,
                    customCharges: data.customCharges || [],
                    totalAmount: data.totalAmount,
                    paymentMode: data.paymentMode || 'Cash',
                    driveFileUrl: returnedInv.driveFileUrl || '',
                    driveDownloadUrl: returnedInv.driveDownloadUrl || ''
                };

                // Cache locally for instant search and offline backup
                cachePatientLocally(data, currentInvoiceData);

                // Show In-Page Success Banner
                showSuccessBanner(data, currentInvoiceData);

                // Show Toast Notification
                showToast(
                    'Patient Registered Successfully! 🎉',
                    `${data.fullName} recorded with Invoice ${currentInvoiceData.invoiceNo}`,
                    'success'
                );

                // Show Form Message
                showMessage('Registration / Revisit saved successfully and recorded in Google Sheet & Google Drive!', 'success');

                // Open Invoice Modal
                openInvoiceModal(currentInvoiceData);

                // Reset form fields
                form.reset();
                calculateTotal();
                if (medicalHistorySelect) medicalHistorySelect.value = '';
                if (medicalHistoryInput) medicalHistoryInput.value = '';
                if (drugAllergiesInput) drugAllergiesInput.value = '';
                if (chiefComplaintInput) chiefComplaintInput.value = '';
                if (diseaseHistoryInput) diseaseHistoryInput.value = '';
                if (treatmentInput) treatmentInput.value = '';
                if (regQuickTreatments) regQuickTreatments.querySelectorAll('.treatment-chip').forEach(c => c.classList.remove('active'));
                if (treatmentSelect) treatmentSelect.value = '';
                if (customTreatmentInput) customTreatmentInput.value = '';
                if (customTreatmentGroup) customTreatmentGroup.style.display = 'none';
                if (registrationDateInput) registrationDateInput.value = new Date().toISOString().split('T')[0];
            } else {
                showMessage(result.message || 'Error saving to Google Sheet. Please try again.', 'error');
                showToast('Registration Error', result.message || 'Error saving record', 'error');
            }
        } catch (error) {
            console.error('Submission error:', error);
            const errMsg = error.message || 'Please check network and Google Script permissions.';
            showMessage('Error submitting registration: ' + errMsg, 'error');
            showToast('Submission Failed', errMsg, 'error');
        } finally {
            submitBtn.disabled = false;
            btnText.style.display = 'block';
            btnLoader.style.display = 'none';
        }
    });

    // 8. Invoice Modal Presentation
    function openInvoiceModal(inv) {
        if (invModalNumber) invModalNumber.textContent = inv.invoiceNo;
        const displayDate = inv.date || (inv.timestamp ? (inv.timestamp.toString().indexOf('T') !== -1 ? inv.timestamp.split('T')[0] : inv.timestamp.toString().split(' ')[0]) : new Date().toLocaleDateString('en-GB'));
        if (invModalDate) invModalDate.textContent = 'Date: ' + displayDate;
        if (invModalPatientName) invModalPatientName.textContent = inv.fullName || inv.patientName || 'Valued Patient';
        if (invModalPhone) invModalPhone.textContent = inv.phone || 'N/A';
        const invModalAddress = document.getElementById('invModalAddress');
        const displayAddress = inv.address || (addressInput ? addressInput.value : '') || (inv.email && inv.email.indexOf('@') === -1 ? inv.email : '') || 'Thrissur, Kerala';
        if (invModalAddress) invModalAddress.textContent = displayAddress;

        // Dynamically build itemized billing table including treatment details and custom charges (# | Treatment | Nos | Rate | Amount)
        const invModalTableBody = document.getElementById('invModalTableBody');
        const invModalTotal = document.getElementById('invModalTotal');
        if (invModalTableBody) {
            let rowHtml = '';
            let rowIdx = 1;
            const consultAmt = parseFloat(inv.consultationCharge) || 0;
            const treatAmt = parseFloat(inv.treatmentCharge) || 0;
            const xrayAmt = parseFloat(inv.xrayCharge) || 0;
            const pharmAmt = parseFloat(inv.pharmacyCharge) || 0;
            const total = parseFloat(inv.totalAmount) || (consultAmt + treatAmt + xrayAmt + pharmAmt);
            const customList = Array.isArray(inv.customCharges) ? inv.customCharges : [];

            const formatNum = (n) => (parseFloat(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

            if (inv.treatment && inv.treatment.trim().length > 0) {
                const nos = inv.nos || 1;
                const amt = treatAmt > 0 ? treatAmt : (total > 0 ? total : 0);
                const rate = inv.rate ? parseFloat(inv.rate) : (amt / nos);
                rowHtml += `<tr>
                    <td style="text-align: center;">${rowIdx++}</td>
                    <td>${escapeHtml(inv.treatment)}</td>
                    <td style="text-align: center;">${nos}</td>
                    <td style="text-align: right;">${formatNum(rate)}</td>
                    <td style="text-align: right;">${formatNum(amt)}</td>
                </tr>`;
            } else if (consultAmt > 0 || (treatAmt === 0 && xrayAmt === 0 && pharmAmt === 0 && customList.length === 0)) {
                const amt = consultAmt > 0 ? consultAmt : total;
                rowHtml += `<tr>
                    <td style="text-align: center;">${rowIdx++}</td>
                    <td>Consultation & Dental Examination</td>
                    <td style="text-align: center;">1</td>
                    <td style="text-align: right;">${formatNum(amt)}</td>
                    <td style="text-align: right;">${formatNum(amt)}</td>
                </tr>`;
            }

            if (treatAmt > 0 && !(inv.treatment && inv.treatment.trim().length > 0)) {
                rowHtml += `<tr>
                    <td style="text-align: center;">${rowIdx++}</td>
                    <td>Dental Treatment & Procedure</td>
                    <td style="text-align: center;">1</td>
                    <td style="text-align: right;">${formatNum(treatAmt)}</td>
                    <td style="text-align: right;">${formatNum(treatAmt)}</td>
                </tr>`;
            }

            if (xrayAmt > 0) {
                rowHtml += `<tr>
                    <td style="text-align: center;">${rowIdx++}</td>
                    <td>X-Ray Radiology Examination</td>
                    <td style="text-align: center;">1</td>
                    <td style="text-align: right;">${formatNum(xrayAmt)}</td>
                    <td style="text-align: right;">${formatNum(xrayAmt)}</td>
                </tr>`;
            }

            if (pharmAmt > 0) {
                rowHtml += `<tr>
                    <td style="text-align: center;">${rowIdx++}</td>
                    <td>Pharmacy & Medicines</td>
                    <td style="text-align: center;">1</td>
                    <td style="text-align: right;">${formatNum(pharmAmt)}</td>
                    <td style="text-align: right;">${formatNum(pharmAmt)}</td>
                </tr>`;
            }

            customList.forEach(c => {
                const amt = parseFloat(c.amount) || 0;
                rowHtml += `<tr>
                    <td style="text-align: center;">${rowIdx++}</td>
                    <td>${escapeHtml(c.title || 'Clinical Procedure')}</td>
                    <td style="text-align: center;">${c.nos || 1}</td>
                    <td style="text-align: right;">${formatNum(parseFloat(c.rate) || amt)}</td>
                    <td style="text-align: right;">${formatNum(amt)}</td>
                </tr>`;
            });

            // Blank spacer row to match reference receipt pad
            rowHtml += `<tr class="spacer-row"><td></td><td></td><td></td><td></td><td></td></tr>`;

            invModalTableBody.innerHTML = rowHtml;
        }

        if (invModalTotal) {
            const tot = parseFloat(inv.totalAmount) || 0;
            invModalTotal.textContent = tot.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        }

        const invModalSign = document.getElementById('invModalSign');
        if (invModalSign) {
            if (typeof window !== 'undefined' && window.INVOICE_SIGN_BASE64) {
                invModalSign.src = window.INVOICE_SIGN_BASE64;
            } else {
                invModalSign.src = 'assets/img/sign.jpg';
            }
        }
        const invModalDrSeal = document.getElementById('invModalDrSeal');
        if (invModalDrSeal && typeof window !== 'undefined' && window.INVOICE_DR_SEAL_BASE64) {
            invModalDrSeal.src = window.INVOICE_DR_SEAL_BASE64;
        } else if (invModalDrSeal) {
            invModalDrSeal.src = 'assets/img/drseal.jpg';
        }
        const invModalSeal = document.getElementById('invModalSeal');
        if (invModalSeal && typeof window !== 'undefined' && window.INVOICE_HOSPITAL_SEAL_BASE64) {
            invModalSeal.src = window.INVOICE_HOSPITAL_SEAL_BASE64;
        } else if (invModalSeal) {
            invModalSeal.src = 'assets/img/Hospital Seal.jpg';
        }

        if (inv.driveFileUrl) {
            invDriveNotice.style.display = 'flex';
            invDriveLink.href = inv.driveFileUrl;
        } else {
            invDriveNotice.style.display = 'none';
        }

        // Cache invoice to dental_cached_invoices
        try {
            const rawInv = localStorage.getItem('dental_cached_invoices');
            const list = rawInv ? JSON.parse(rawInv) : [];
            const idx = list.findIndex(i => (i.invoiceNo || i.id) === (inv.invoiceNo || inv.id));
            if (idx === -1) {
                list.unshift(inv);
                localStorage.setItem('dental_cached_invoices', JSON.stringify(list.slice(0, 100)));
            }
        } catch(e) {}

        invoiceModalOverlay.classList.add('active');
    }

    function closeInvoiceModal() {
        invoiceModalOverlay.classList.remove('active');
    }

    if (closeInvoiceModalBtn) closeInvoiceModalBtn.addEventListener('click', closeInvoiceModal);
    if (doneInvoiceBtn) doneInvoiceBtn.addEventListener('click', closeInvoiceModal);

    // Toggle Black & White Mode on Screen
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

    // Print Invoice Handler (crisp Black & White compatible)
    if (printInvoiceBtn) {
        printInvoiceBtn.addEventListener('click', () => {
            document.body.classList.add('printing-invoice');
            window.print();
            setTimeout(() => {
                document.body.classList.remove('printing-invoice');
            }, 1000);
        });
    }

    // Download / Save PDF Invoice Handler
    if (downloadInvoiceBtn) {
        downloadInvoiceBtn.addEventListener('click', () => {
            if (!currentInvoiceData) return;

            // Open clean printable invoice preview for direct PDF saving/printing
            const invoiceHtml = generatePrintableHtml(currentInvoiceData);
            const printWin = window.open('', '_blank');
            if (printWin) {
                printWin.document.open();
                printWin.document.write(invoiceHtml);
                printWin.document.close();
            } else {
                const blob = new Blob([invoiceHtml], { type: 'text/html;charset=utf-8' });
                const url = URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `Invoice_${currentInvoiceData.invoiceNo}_${currentInvoiceData.fullName.replace(/\s+/g, '_')}.html`;
                document.body.appendChild(a);
                a.click();
                document.body.removeChild(a);
                URL.revokeObjectURL(url);
            }
        });
    }

    // Share Invoice to WhatsApp Handler (proper clinic branding)
    if (shareWhatsappBtn) {
        shareWhatsappBtn.addEventListener('click', () => {
            if (!currentInvoiceData) return;
            const inv = currentInvoiceData;
            const displayDate = inv.date || (inv.timestamp ? inv.timestamp.split(' ')[0] : '') || inv.timestamp;
            const text = `🏥 *MANJALY MULTI SPECIALITY DENTAL CARE*
📍 Valakkavu, Thrissur, Kerala 680751
📞 Phone: +91 9072467117, +91 6238497517 | ✉️ manjalymdc@gmail.com
━━━━━━━━━━━━━━━━━━━━━━━━
🧾 *OFFICIAL PATIENT INVOICE & RECEIPT*
━━━━━━━━━━━━━━━━━━━━━━━━
*Invoice No:* ${inv.invoiceNo}
*Date:* ${displayDate}
*Patient Name:* ${inv.fullName}
*Phone:* ${inv.phone || 'N/A'}
*Doctor Consulted:* ${inv.doctorConsulted}
*Treatment Details:* ${inv.treatment || inv.diseaseHistory || 'General Consultation'}

*CHARGES BREAKDOWN:*
${(() => {
    let lines = [];
    if (parseFloat(inv.consultationCharge) > 0) lines.push(`• Consultation Fee: ₹${parseFloat(inv.consultationCharge).toFixed(2)}`);
    if (parseFloat(inv.treatmentCharge) > 0) lines.push(`• Treatment (${inv.treatment || 'Procedure'}): ₹${parseFloat(inv.treatmentCharge).toFixed(2)}`);
    if (parseFloat(inv.xrayCharge) > 0) lines.push(`• X-Ray / Radiology: ₹${parseFloat(inv.xrayCharge).toFixed(2)}`);
    if (parseFloat(inv.pharmacyCharge) > 0) lines.push(`• Pharmacy / Medicines: ₹${parseFloat(inv.pharmacyCharge).toFixed(2)}`);
    if (Array.isArray(inv.customCharges)) {
        inv.customCharges.forEach(c => {
            lines.push(`• ${c.title || 'Custom Charge'}: ₹${(parseFloat(c.amount) || 0).toFixed(2)}`);
        });
    }
    if (lines.length === 0) lines.push(`• Consultation Fee: ₹${parseFloat(inv.totalAmount || 0).toFixed(2)}`);
    return lines.join('\n');
})()}
────────────────────────
*TOTAL AMOUNT:* ₹${parseFloat(inv.totalAmount).toFixed(2)}
*Payment Mode:* PAID (${inv.paymentMode || 'Cash'})
────────────────────────
*Hospital:* Manjaly Multi Speciality Dental Care
Thank you for choosing Manjaly Dental Care!
Wishing you good oral health!
━━━━━━━━━━━━━━━━━━━━━━━━`;

            const phoneDigits = (inv.phone || '').replace(/\\D/g, '');
            const targetPhone = phoneDigits.length === 10 ? ('91' + phoneDigits) : phoneDigits;
            const waUrl = targetPhone.length >= 10
                ? `https://api.whatsapp.com/send?phone=${targetPhone}&text=${encodeURIComponent(text)}`
                : `https://api.whatsapp.com/send?text=${encodeURIComponent(text)}`;
            window.open(waUrl, '_blank');
        });
    }

    function generatePrintableHtml(inv) {
        const displayDate = inv.date || (inv.timestamp ? (inv.timestamp.toString().indexOf('T') !== -1 ? inv.timestamp.split('T')[0] : inv.timestamp.toString().split(' ')[0]) : new Date().toLocaleDateString('en-GB'));
        const displayAddress = inv.address || (inv.email && inv.email.indexOf('@') === -1 ? inv.email : '') || 'Thrissur, Kerala';
        const logoSrc = (typeof window !== 'undefined' && window.INVOICE_LOGO_BASE64) ? window.INVOICE_LOGO_BASE64 : 'assets/img/logo.png';
        const signSrc = (typeof window !== 'undefined' && window.INVOICE_SIGN_BASE64) ? window.INVOICE_SIGN_BASE64 : 'assets/img/sign.jpg';
        const drSealSrc = (typeof window !== 'undefined' && window.INVOICE_DR_SEAL_BASE64) ? window.INVOICE_DR_SEAL_BASE64 : 'assets/img/drseal.jpg';
        const hospSealSrc = (typeof window !== 'undefined' && window.INVOICE_HOSPITAL_SEAL_BASE64) ? window.INVOICE_HOSPITAL_SEAL_BASE64 : 'assets/img/Hospital Seal.jpg';

        const cAmt = parseFloat(inv.consultationCharge) || 0;
        const tAmt = parseFloat(inv.treatmentCharge) || 0;
        const xAmt = parseFloat(inv.xrayCharge) || 0;
        const pAmt = parseFloat(inv.pharmacyCharge) || 0;
        const total = parseFloat(inv.totalAmount) || (cAmt + tAmt + xAmt + pAmt);
        const customs = Array.isArray(inv.customCharges) ? inv.customCharges : [];

        const formatNum = (n) => (parseFloat(n) || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
        let rowsHtml = '';
        let rIdx = 1;

        if (inv.treatment && inv.treatment.trim().length > 0) {
            const nos = inv.nos || 1;
            const amt = tAmt > 0 ? tAmt : (total > 0 ? total : 0);
            const rate = inv.rate ? parseFloat(inv.rate) : (amt / nos);
            rowsHtml += `<tr>
                <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px;">${rIdx++}</td>
                <td style="border-right: 1px solid #000; padding: 7px 10px;">${escapeHtml(inv.treatment)}</td>
                <td style="text-align: center; border-right: 1px solid #000; padding: 7px 10px;">${nos}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(rate)}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(amt)}</td>
            </tr>`;
        } else if (cAmt > 0 || (tAmt === 0 && xAmt === 0 && pAmt === 0 && customs.length === 0)) {
            const amt = cAmt > 0 ? cAmt : total;
            rowsHtml += `<tr>
                <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px;">${rIdx++}</td>
                <td style="border-right: 1px solid #000; padding: 7px 10px;">Consultation & Dental Examination</td>
                <td style="text-align: center; border-right: 1px solid #000; padding: 7px 10px;">1</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(amt)}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(amt)}</td>
            </tr>`;
        }

        if (tAmt > 0 && !(inv.treatment && inv.treatment.trim().length > 0)) {
            rowsHtml += `<tr>
                <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px;">${rIdx++}</td>
                <td style="border-right: 1px solid #000; padding: 7px 10px;">Dental Treatment & Procedure</td>
                <td style="text-align: center; border-right: 1px solid #000; padding: 7px 10px;">1</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(tAmt)}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(tAmt)}</td>
            </tr>`;
        }

        if (xAmt > 0) {
            rowsHtml += `<tr>
                <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px;">${rIdx++}</td>
                <td style="border-right: 1px solid #000; padding: 7px 10px;">X-Ray Radiology Examination</td>
                <td style="text-align: center; border-right: 1px solid #000; padding: 7px 10px;">1</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(xAmt)}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(xAmt)}</td>
            </tr>`;
        }

        if (pAmt > 0) {
            rowsHtml += `<tr>
                <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px;">${rIdx++}</td>
                <td style="border-right: 1px solid #000; padding: 7px 10px;">Pharmacy & Medicines</td>
                <td style="text-align: center; border-right: 1px solid #000; padding: 7px 10px;">1</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(pAmt)}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(pAmt)}</td>
            </tr>`;
        }

        customs.forEach(c => {
            const amt = parseFloat(c.amount) || 0;
            rowsHtml += `<tr>
                <td style="text-align: center; border-left: 1px solid #000; border-right: 1px solid #000; padding: 7px 10px;">${rIdx++}</td>
                <td style="border-right: 1px solid #000; padding: 7px 10px;">${escapeHtml(c.title || 'Clinical Procedure')}</td>
                <td style="text-align: center; border-right: 1px solid #000; padding: 7px 10px;">${c.nos || 1}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(parseFloat(c.rate) || amt)}</td>
                <td style="text-align: right; border-right: 1px solid #000; padding: 7px 10px;">${formatNum(amt)}</td>
            </tr>`;
        });

        // Blank spacer row to match reference receipt pad
        rowsHtml += `<tr><td style="height: 180px; border-left: 1px solid #000; border-right: 1px solid #000;"></td><td style="border-right: 1px solid #000;"></td><td style="border-right: 1px solid #000;"></td><td style="border-right: 1px solid #000;"></td><td style="border-right: 1px solid #000;"></td></tr>`;

        return `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Invoice - ${inv.invoiceNo}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif; padding: 25px; color: #000; background: #fff; margin: 0; }
        .invoice-box { max-width: 680px; margin: auto; padding: 20px 24px; }
        .header { display: flex; justify-content: space-between; align-items: flex-start; padding-bottom: 8px; }
        .clinic-title { font-size: 20px; font-weight: 900; color: #000000; letter-spacing: 0.3px; text-transform: uppercase; margin: 0; line-height: 1.25; }
        .clinic-addr { font-size: 12px; font-weight: 500; color: #222; margin-top: 4px; }
        .clinic-phone { font-size: 12px; font-weight: 600; color: #000; margin-top: 2px; }
        .logo { max-height: 72px; max-width: 110px; object-fit: contain; }
        .divider { height: 18px; margin: 0; }
        .meta-row { display: flex; justify-content: space-between; font-size: 13.5px; margin-bottom: 16px; }
        .meta-left { display: flex; flex-direction: column; gap: 4px; }
        .meta-line { display: flex; }
        .meta-lbl { width: 70px; font-weight: bold; }
        .meta-sep { margin: 0 10px 0 2px; font-weight: bold; }
        .meta-val { font-weight: normal; }
        table { width: 100%; border-collapse: collapse; border: 1px solid #000; margin-bottom: 24px; font-size: 12.5px; }
        th { border: 1px solid #000; background: #fff; padding: 8px 10px; font-weight: bold; }
        td { border-top: 1px solid #000; padding: 7px 10px; }
        .net-row td { border-top: 1px solid #000; border-bottom: 1px solid #000; font-weight: bold; font-size: 13.5px; padding: 8px 10px; }
        .footer { display: flex; justify-content: space-between; align-items: center; margin-top: 25px; padding: 0 5px; }
        .hosp-seal { max-height: 95px; max-width: 140px; object-fit: contain; }
        .company-text { font-size: 11px; font-weight: bold; text-transform: uppercase; text-align: center; flex: 1; padding: 0 12px; }
        .sign-wrap { display: flex; justify-content: flex-end; align-items: flex-end; gap: 8px; }
        .sign-img { max-height: 52px; max-width: 95px; object-fit: contain; }
        .drseal-img { max-height: 55px; max-width: 85px; object-fit: contain; }
        @media print {
            body { padding: 0; }
            .invoice-box { border: none; padding: 0; }
        }
    </style>
</head>
<body onload="window.print()">
    <div class="invoice-box">
        <div class="header">
            <div>
                <h1 class="clinic-title">MANJALY MULTI SPECIALITY DENTAL CARE</h1>
                <div class="clinic-addr">Near MJ Supermarket ,Valakkavu Mulayam p.o,Thrissur,Kerala-680751</div>
                <div class="clinic-phone">Mobile: 6238497517,9072467117</div>
            </div>
            <img src="${logoSrc}" alt="Dental Care Logo" class="logo">
        </div>
        <div class="divider"></div>
        <div class="meta-row">
            <div class="meta-left">
                <div class="meta-line"><span class="meta-lbl">Bill No</span><span class="meta-sep">:</span><span class="meta-val" style="font-weight: bold;">${inv.invoiceNo.replace(/^INV-/, '')}</span></div>
                <div class="meta-line"><span class="meta-lbl">Name</span><span class="meta-sep">:</span><span class="meta-val">${inv.fullName}</span></div>
                <div class="meta-line"><span class="meta-lbl">Address</span><span class="meta-sep">:</span><span class="meta-val">${displayAddress}</span></div>
            </div>
            <div>
                <div class="meta-line"><span class="meta-lbl">Date</span><span class="meta-sep">:</span><span class="meta-val" style="font-weight: bold;">${displayDate}</span></div>
            </div>
        </div>
        <table>
            <thead>
                <tr>
                    <th style="width: 7%; text-align: center;">#</th>
                    <th style="width: 50%; text-align: left;">Treatment</th>
                    <th style="width: 11%; text-align: center;">Nos</th>
                    <th style="width: 16%; text-align: right;">Rate</th>
                    <th style="width: 16%; text-align: right;">Amount</th>
                </tr>
            </thead>
            <tbody>
                ${rowsHtml}
            </tbody>
            <tfoot>
                <tr class="net-row">
                    <td colspan="4" style="text-align: right; border-right: 1px solid #000;">Net Amount Rs:</td>
                    <td style="text-align: right;">${formatNum(total)}</td>
                </tr>
            </tfoot>
        </table>
        <div class="footer">
            <img src="${hospSealSrc}" alt="Hospital Seal" class="hosp-seal">
            <div class="company-text">FOR MANJALY MULTI SPECIALITY DENTAL CARE</div>
            <div class="sign-wrap">
                <img src="${signSrc}" alt="Doctor Signature" class="sign-img">
                <img src="${drSealSrc}" alt="Doctor Seal" class="drseal-img">
            </div>
        </div>
    </div>
</body>
</html>`;
    }

    function showMessage(msg, type) {
        if (!formMessage) return;
        formMessage.textContent = msg;
        formMessage.className = `form-message ${type}`;
        formMessage.style.display = 'block';
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
