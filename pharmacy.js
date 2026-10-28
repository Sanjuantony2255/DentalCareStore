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
    const pharmacyLoader = document.getElementById('pharmacyLoader');
    const pharmacyMessage = document.getElementById('pharmacyMessage');
    const refreshStockBtn = document.getElementById('refreshStockBtn');
    const totalItemsDisplay = document.getElementById('totalItemsDisplay');
    const lowStockDisplay = document.getElementById('lowStockDisplay');
    const expiringDisplay = document.getElementById('expiringDisplay');
    const totalValueDisplay = document.getElementById('totalValueDisplay');

    const stockFilterGroup = document.getElementById('stockFilterGroup');
    const stockSearchInput = document.getElementById('stockSearchInput');
    const categoryFilterSelect = document.getElementById('categoryFilterSelect');
    const stockTableBody = document.getElementById('stockTableBody');
    const printStockBtn = document.getElementById('printStockBtn');
    const exportStockCsvBtn = document.getElementById('exportStockCsvBtn');

    // Add Stock Modal
    const openAddStockModalBtn = document.getElementById('openAddStockModalBtn');
    const addStockModalOverlay = document.getElementById('addStockModalOverlay');
    const closeAddStockModalBtn = document.getElementById('closeAddStockModalBtn');
    const cancelAddStockBtn = document.getElementById('cancelAddStockBtn');
    const addStockForm = document.getElementById('addStockForm');
    const saveStockBtn = document.getElementById('saveStockBtn');

    // Form Fields
    const addItemName = document.getElementById('addItemName');
    const addItemCategory = document.getElementById('addItemCategory');
    const addItemBatch = document.getElementById('addItemBatch');
    const addItemExpiry = document.getElementById('addItemExpiry');
    const addItemPrice = document.getElementById('addItemPrice');
    const addItemQuantity = document.getElementById('addItemQuantity');
    const addItemThreshold = document.getElementById('addItemThreshold');
    const addItemSupplier = document.getElementById('addItemSupplier');

    // No dummy items - strictly only display data from Google Sheet
    const DEFAULT_STOCK_ITEMS = [];

    // Local Storage Key
    const STORAGE_KEY = 'dentalcare_pharmacy_stock_v1';
    try {
        localStorage.removeItem(STORAGE_KEY);
    } catch(e) {}

    let currentStockItems = [];
    let activePillFilter = 'all';

    // Set default expiry date to 1 year ahead
    if (addItemExpiry) {
        const nextYear = new Date();
        nextYear.setFullYear(nextYear.getFullYear() + 1);
        addItemExpiry.value = nextYear.toISOString().slice(0, 10);
    }

    // Modal open/close listeners
    if (openAddStockModalBtn) {
        openAddStockModalBtn.addEventListener('click', () => {
            if (addStockForm) addStockForm.reset();
            if (addItemExpiry) {
                const nextYear = new Date();
                nextYear.setFullYear(nextYear.getFullYear() + 1);
                addItemExpiry.value = nextYear.toISOString().slice(0, 10);
            }
            if (addItemThreshold) addItemThreshold.value = '20';
            if (addStockModalOverlay) addStockModalOverlay.classList.add('active');
        });
    }

    if (closeAddStockModalBtn) {
        closeAddStockModalBtn.addEventListener('click', () => {
            if (addStockModalOverlay) addStockModalOverlay.classList.remove('active');
        });
    }

    if (cancelAddStockBtn) {
        cancelAddStockBtn.addEventListener('click', () => {
            if (addStockModalOverlay) addStockModalOverlay.classList.remove('active');
        });
    }

    // Filter pill buttons
    if (stockFilterGroup) {
        stockFilterGroup.querySelectorAll('.period-pill-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                stockFilterGroup.querySelectorAll('.period-pill-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                activePillFilter = btn.getAttribute('data-filter');
                renderStockTable();
            });
        });
    }

    // Search and Category filter listeners
    if (stockSearchInput) {
        stockSearchInput.addEventListener('input', () => {
            renderStockTable();
        });
    }
    if (categoryFilterSelect) {
        categoryFilterSelect.addEventListener('change', () => {
            renderStockTable();
        });
    }

    // Refresh listener
    if (refreshStockBtn) {
        refreshStockBtn.addEventListener('click', () => {
            loadPharmacyStock();
        });
    }

    // Print & Export
    if (printStockBtn) {
        printStockBtn.addEventListener('click', () => {
            window.print();
        });
    }

    if (exportStockCsvBtn) {
        exportStockCsvBtn.addEventListener('click', () => {
            exportStockCsv();
        });
    }

    // Handle Add Stock Form submission
    if (addStockForm) {
        addStockForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            const name = addItemName.value.trim();
            const category = addItemCategory.value.trim();
            const batchNo = addItemBatch.value.trim() || ('BT-' + Date.now().toString().slice(-6));
            const expiryDate = addItemExpiry.value.trim();
            const unitPrice = parseFloat(addItemPrice.value) || 0;
            const quantity = parseInt(addItemQuantity.value, 10) || 0;
            const minThreshold = parseInt(addItemThreshold.value, 10) || 10;
            const supplier = addItemSupplier.value.trim() || 'General Medical';

            if (!name) {
                alert('Please enter medicine name');
                return;
            }

            saveStockBtn.disabled = true;
            saveStockBtn.textContent = 'Saving...';

            const newItem = {
                itemId: 'MED-' + (1000 + currentStockItems.length + 1),
                itemName: name,
                category: category,
                batchNo: batchNo,
                expiryDate: expiryDate,
                unitPrice: unitPrice,
                quantity: quantity,
                minThreshold: minThreshold,
                supplier: supplier,
                lastUpdated: new Date().toISOString().slice(0, 16).replace('T', ' ')
            };

            // Post to backend Google Apps Script
            try {
                fetch(SCRIPT_URL, {
                    method: 'POST',
                    headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                    body: JSON.stringify({
                        action: 'addPharmacyItem',
                        ...newItem
                    })
                }).catch(err => console.log('Sync to Google Apps Script queued', err));
            } catch(e) {}

            // Immediately add to local state and update UI
            currentStockItems.unshift(newItem);
            saveToLocalStorage();
            updateSummaryCards();
            renderStockTable();

            showMessage(`Medicine "${name}" added to pharmacy stock successfully!`, 'success');
            if (addStockModalOverlay) addStockModalOverlay.classList.remove('active');
            addStockForm.reset();

            saveStockBtn.disabled = false;
            saveStockBtn.innerHTML = '<span>💾</span> Save Stock Item';
        });
    }

    // Load Stock from server or local cache
    // Load Stock from Google Sheet
    async function loadPharmacyStock() {
        showLoader(true);
        hideMessage();

        try {
            const res = await fetch(`${SCRIPT_URL}?action=getPharmacyStock`);
            const json = await res.json();

            if (json && json.status === 'success' && Array.isArray(json.data)) {
                currentStockItems = json.data;
                saveToLocalStorage();
            } else {
                currentStockItems = [];
            }
        } catch (err) {
            console.log('Pharmacy load network notice:', err);
            loadFromCacheOrDefault();
        } finally {
            showLoader(false);
            updateSummaryCards();
            renderStockTable();
        }
    }

    function loadFromCacheOrDefault() {
        currentStockItems = [];
    }

    function saveToLocalStorage() {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(currentStockItems));
        } catch(e) {}
    }

    // Update 4 overview cards
    function updateSummaryCards() {
        const totalItems = currentStockItems.length;
        let lowCount = 0;
        let expiringCount = 0;
        let totalVal = 0;

        const now = new Date();
        const ninetyDays = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);

        currentStockItems.forEach(item => {
            const qty = parseInt(item.quantity, 10) || 0;
            const threshold = parseInt(item.minThreshold, 10) || 10;
            const price = parseFloat(item.unitPrice) || 0;

            totalVal += (qty * price);

            if (qty <= threshold) {
                lowCount++;
            }

            if (item.expiryDate) {
                const expDate = new Date(item.expiryDate);
                if (!isNaN(expDate.getTime()) && expDate <= ninetyDays) {
                    expiringCount++;
                }
            }
        });

        if (totalItemsDisplay) totalItemsDisplay.textContent = totalItems;
        if (lowStockDisplay) lowStockDisplay.textContent = lowCount;
        if (expiringDisplay) expiringDisplay.textContent = expiringCount;
        if (totalValueDisplay) {
            totalValueDisplay.textContent = `₹${totalVal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
        }
    }

    // Render Inventory Table
    function renderStockTable() {
        if (!stockTableBody) return;

        const q = (stockSearchInput ? stockSearchInput.value : '').toLowerCase().trim();
        const catFilter = (categoryFilterSelect ? categoryFilterSelect.value : 'all').toLowerCase();

        const now = new Date();
        const ninetyDays = new Date(now.getTime() + 90 * 24 * 60 * 60 * 1000);

        const filtered = currentStockItems.filter(item => {
            const qty = parseInt(item.quantity, 10) || 0;
            const threshold = parseInt(item.minThreshold, 10) || 10;
            const expDate = item.expiryDate ? new Date(item.expiryDate) : null;
            const isExpiring = expDate && !isNaN(expDate.getTime()) && expDate <= ninetyDays;
            const isLow = qty <= threshold;

            // Pill filter
            if (activePillFilter === 'low' && !isLow) return false;
            if (activePillFilter === 'expiring' && !isExpiring) return false;
            if (activePillFilter === 'instock' && isLow) return false;

            // Category filter
            if (catFilter !== 'all') {
                const itemCat = (item.category || '').toLowerCase();
                if (!itemCat.includes(catFilter)) return false;
            }

            // Text search
            if (q) {
                const name = (item.itemName || '').toLowerCase();
                const code = (item.itemId || '').toLowerCase();
                const batch = (item.batchNo || '').toLowerCase();
                const cat = (item.category || '').toLowerCase();
                if (!name.includes(q) && !code.includes(q) && !batch.includes(q) && !cat.includes(q)) {
                    return false;
                }
            }

            return true;
        });

        if (filtered.length === 0) {
            stockTableBody.innerHTML = `
                <tr>
                    <td colspan="9" style="text-align: center; padding: 2.5rem; color: #64748b;">
                        <span>📦 No medicine or clinical stock items match your filter.</span>
                    </td>
                </tr>
            `;
            return;
        }

        stockTableBody.innerHTML = filtered.map((item, idx) => {
            const qty = parseInt(item.quantity, 10) || 0;
            const threshold = parseInt(item.minThreshold, 10) || 10;
            const price = parseFloat(item.unitPrice) || 0;
            const expDate = item.expiryDate ? new Date(item.expiryDate) : null;
            const isExpired = expDate && !isNaN(expDate.getTime()) && expDate < now;
            const isExpiring = expDate && !isNaN(expDate.getTime()) && expDate <= ninetyDays && !isExpired;

            let statusBadge = '<span class="badge-stock-in">In Stock</span>';
            if (qty === 0) {
                statusBadge = '<span class="badge-stock-out">Out of Stock</span>';
            } else if (qty <= threshold) {
                statusBadge = `<span class="badge-stock-low">Low Stock (${qty})</span>`;
            } else if (isExpired) {
                statusBadge = '<span class="badge-stock-out">Expired</span>';
            } else if (isExpiring) {
                statusBadge = '<span class="badge-stock-expiring">Expiring Soon</span>';
            }

            return `
                <tr>
                    <td style="font-weight: 700; color: #1e3a8a;">${escapeHtml(item.itemId || '')}</td>
                    <td>
                        <strong style="color: #0f172a;">${escapeHtml(item.itemName || '')}</strong>
                        ${item.supplier ? `<div style="font-size: 0.75rem; color: #64748b;">${escapeHtml(item.supplier)}</div>` : ''}
                    </td>
                    <td><span style="background: #f1f5f9; padding: 2px 8px; border-radius: 6px; font-size: 0.8rem; font-weight: 600; color: #475569;">${escapeHtml(item.category || 'General')}</span></td>
                    <td style="font-family: monospace; font-size: 0.85rem;">${escapeHtml(item.batchNo || 'N/A')}</td>
                    <td style="${isExpired ? 'color: #dc2626; font-weight: 700;' : (isExpiring ? 'color: #d97706; font-weight: 600;' : '')}">
                        ${escapeHtml(item.expiryDate || 'N/A')}
                    </td>
                    <td class="amount-col">₹${price.toFixed(2)}</td>
                    <td class="amount-col" style="${qty <= threshold ? 'color: #d97706; font-weight: 700;' : 'font-weight: 600;'}">
                        ${qty}
                    </td>
                    <td>${statusBadge}</td>
                    <td style="text-align: center;">
                        <div style="display: inline-flex; gap: 4px; align-items: center;">
                            <button type="button" class="qty-action-btn minus-btn" data-item-id="${escapeHtml(item.itemId)}" title="Dispense 1 Unit">-</button>
                            <button type="button" class="qty-action-btn plus-btn" data-item-id="${escapeHtml(item.itemId)}" title="Restock +10 Units">+</button>
                        </div>
                    </td>
                </tr>
            `;
        }).join('');

        // Attach quick adjustment handlers
        stockTableBody.querySelectorAll('.plus-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = btn.getAttribute('data-item-id');
                adjustStockQuantity(id, +10);
            });
        });

        stockTableBody.querySelectorAll('.minus-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                const id = btn.getAttribute('data-item-id');
                adjustStockQuantity(id, -1);
            });
        });
    }

    // Quick Quantity Adjust (+ / -)
    function adjustStockQuantity(itemId, change) {
        const item = currentStockItems.find(i => i.itemId === itemId);
        if (!item) return;

        const currentQty = parseInt(item.quantity, 10) || 0;
        const newQty = Math.max(0, currentQty + change);
        item.quantity = newQty;
        item.lastUpdated = new Date().toISOString().slice(0, 16).replace('T', ' ');

        saveToLocalStorage();
        updateSummaryCards();
        renderStockTable();

        // Push update to Google Apps Script backend
        try {
            fetch(SCRIPT_URL, {
                method: 'POST',
                headers: { 'Content-Type': 'text/plain;charset=utf-8' },
                body: JSON.stringify({
                    action: 'updatePharmacyStock',
                    itemId: itemId,
                    changeQty: change
                })
            }).catch(e => console.log('Apps script stock update notice', e));
        } catch(e) {}
    }

    // Export CSV
    function exportStockCsv() {
        if (!currentStockItems || currentStockItems.length === 0) {
            alert('No stock items to export.');
            return;
        }

        const headers = ['Item ID', 'Medicine Name', 'Category', 'Batch No', 'Expiry Date', 'Unit Price (INR)', 'Current Stock Quantity', 'Min Threshold', 'Supplier'];
        const rows = [headers.join(',')];

        currentStockItems.forEach(i => {
            const row = [
                `"${(i.itemId || '').replace(/"/g, '""')}"`,
                `"${(i.itemName || '').replace(/"/g, '""')}"`,
                `"${(i.category || '').replace(/"/g, '""')}"`,
                `"${(i.batchNo || '').replace(/"/g, '""')}"`,
                `"${(i.expiryDate || '').replace(/"/g, '""')}"`,
                (parseFloat(i.unitPrice) || 0).toFixed(2),
                parseInt(i.quantity, 10) || 0,
                parseInt(i.minThreshold, 10) || 10,
                `"${(i.supplier || '').replace(/"/g, '""')}"`
            ];
            rows.push(row.join(','));
        });

        const csvContent = 'data:text/csv;charset=utf-8,' + encodeURIComponent(rows.join('\n'));
        const downloadAnchor = document.createElement('a');
        downloadAnchor.setAttribute('href', csvContent);
        downloadAnchor.setAttribute('download', `DentalCare_Pharmacy_Stock_${new Date().toISOString().slice(0, 10)}.csv`);
        document.body.appendChild(downloadAnchor);
        downloadAnchor.click();
        downloadAnchor.remove();
    }

    function showLoader(show) {
        if (pharmacyLoader) pharmacyLoader.style.display = show ? 'block' : 'none';
        if (refreshStockBtn) refreshStockBtn.disabled = show;
    }

    function showMessage(msg, type) {
        if (!pharmacyMessage) return;
        pharmacyMessage.textContent = msg;
        pharmacyMessage.className = `message-banner ${type === 'error' ? 'error' : 'success'}`;
        pharmacyMessage.style.display = 'block';
    }

    function hideMessage() {
        if (pharmacyMessage) pharmacyMessage.style.display = 'none';
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
    loadPharmacyStock();
});
