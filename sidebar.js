/**
 * Dental Care Clinic & Hospital
 * Universal Sidebar Controller (Desktop Collapse & Mobile Drawer)
 */
(function() {
    function initSidebar() {
        const appSidebar = document.getElementById('appSidebar');
        const sidebarOverlay = document.getElementById('sidebarOverlay');
        const sidebarToggleBtn = document.getElementById('sidebarToggleBtn');
        const sidebarCloseBtn = document.getElementById('sidebarCloseBtn');
        const sidebarCollapseBtn = document.getElementById('sidebarCollapseBtn');
        const appLayout = document.querySelector('.app-layout');

        if (!appSidebar) return;

        // 1. Restore Desktop Minimized / Collapsed state
        const isCollapsed = localStorage.getItem('dental_sidebar_collapsed') === 'true';
        if (isCollapsed) {
            appSidebar.classList.add('collapsed');
            if (appLayout) appLayout.classList.add('sidebar-collapsed');
            if (sidebarCollapseBtn) {
                sidebarCollapseBtn.setAttribute('title', 'Expand Sidebar');
                sidebarCollapseBtn.setAttribute('aria-expanded', 'false');
            }
        } else {
            if (sidebarCollapseBtn) {
                sidebarCollapseBtn.setAttribute('title', 'Minimize Sidebar');
                sidebarCollapseBtn.setAttribute('aria-expanded', 'true');
            }
        }

        // 2. Desktop Collapse / Minimize Toggle Handler
        if (sidebarCollapseBtn) {
            sidebarCollapseBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();

                const willCollapse = !appSidebar.classList.contains('collapsed');
                appSidebar.classList.toggle('collapsed', willCollapse);
                if (appLayout) appLayout.classList.toggle('sidebar-collapsed', willCollapse);

                localStorage.setItem('dental_sidebar_collapsed', willCollapse ? 'true' : 'false');
                sidebarCollapseBtn.setAttribute('title', willCollapse ? 'Expand Sidebar' : 'Minimize Sidebar');
                sidebarCollapseBtn.setAttribute('aria-expanded', willCollapse ? 'false' : 'true');

                // Trigger window resize event to let charts or tables adjust
                window.dispatchEvent(new Event('resize'));
            });
        }

        // 3. Mobile / Responsive Drawer Toggle Handler
        function openMobileDrawer() {
            appSidebar.classList.add('open');
            if (sidebarOverlay) {
                sidebarOverlay.classList.add('active');
            }
            document.body.classList.add('drawer-open');
        }

        function closeMobileDrawer() {
            appSidebar.classList.remove('open');
            if (sidebarOverlay) {
                sidebarOverlay.classList.remove('active');
            }
            document.body.classList.remove('drawer-open');
        }

        if (sidebarToggleBtn) {
            sidebarToggleBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                if (appSidebar.classList.contains('open')) {
                    closeMobileDrawer();
                } else {
                    openMobileDrawer();
                }
            });
        }

        if (sidebarCloseBtn) {
            sidebarCloseBtn.addEventListener('click', (e) => {
                e.preventDefault();
                closeMobileDrawer();
            });
        }

        if (sidebarOverlay) {
            sidebarOverlay.addEventListener('click', () => {
                closeMobileDrawer();
            });
        }

        // Auto-close drawer on mobile when clicking any navigation link
        const navLinks = appSidebar.querySelectorAll('.sidebar-link');
        navLinks.forEach(link => {
            link.addEventListener('click', (e) => {
                // If this is the accounts link and current role is staff, intercept
                if (link.getAttribute('href') === 'accounts.html' && getRole() === 'staff') {
                    e.preventDefault();
                    showAdminRequiredModal();
                    return;
                }
                if (window.innerWidth <= 992) {
                    closeMobileDrawer();
                }
            });
        });

        // 4. Role Management: Admin vs Staff
        // 4. Role Management: Admin vs Staff (Owner: Dr. Jeswin)
        const ADMIN_PASSWORD = '118022';

        function getRole() {
            return sessionStorage.getItem('dental_user_role') || 'staff';
        }

        function showRoleToast(msg, type) {
            let container = document.getElementById('toastContainer');
            if (!container) {
                container = document.createElement('div');
                container.id = 'toastContainer';
                container.className = 'toast-container';
                document.body.appendChild(container);
            }
            const toast = document.createElement('div');
            toast.className = `toast ${type === 'success' ? 'toast-success' : 'toast-error'}`;
            toast.style.cssText = (type === 'success') 
                ? 'background:#0f766e;color:white;padding:0.75rem 1.25rem;border-radius:8px;font-weight:700;margin-top:8px;box-shadow:0 4px 12px rgba(0,0,0,0.15);animation:fadeIn 0.25s ease;'
                : 'background:#dc2626;color:white;padding:0.75rem 1.25rem;border-radius:8px;font-weight:700;margin-top:8px;box-shadow:0 4px 12px rgba(0,0,0,0.15);animation:fadeIn 0.25s ease;';
            toast.textContent = msg;
            container.appendChild(toast);
            setTimeout(() => { toast.remove(); }, 3500);
        }

        function actuallySetRole(role) {
            sessionStorage.setItem('dental_user_role', role);
            try {
                localStorage.removeItem('dental_user_role');
            } catch (_) {}
            applyRoleState();
            window.dispatchEvent(new CustomEvent('dental_role_changed', { detail: { role } }));
        }

        function promptAdminPassword(onSuccess) {
            const existing = document.getElementById('adminPasswordModal');
            if (existing) existing.remove();

            const modal = document.createElement('div');
            modal.id = 'adminPasswordModal';
            modal.style.cssText = 'position:fixed;inset:0;background:rgba(15,23,42,0.65);backdrop-filter:blur(4px);display:flex;align-items:center;justify-content:center;z-index:999999;padding:1rem;';
            modal.innerHTML = `
                <div style="background:white;border-radius:16px;max-width:400px;width:100%;padding:1.75rem;box-shadow:0 20px 25px -5px rgba(0,0,0,0.25);animation:fadeIn 0.2s ease;">
                    <div style="display:flex;align-items:center;gap:12px;margin-bottom:1.25rem;">
                        <div style="width:48px;height:48px;border-radius:50%;background:#fee2e2;color:#dc2626;font-size:1.4rem;display:flex;align-items:center;justify-content:center;flex-shrink:0;">🔒</div>
                        <div>
                            <h3 style="font-size:1.15rem;font-weight:800;color:#0f172a;margin:0 0 2px 0;">Admin Password Required (Dr. Jeswin)</h3>
                            <p style="font-size:0.82rem;color:#64748b;margin:0;">Enter administrator password to access Admin mode.</p>
                        </div>
                    </div>
                    <form id="adminPasswordForm" style="margin:0;">
                        <div style="margin-bottom:1.25rem;">
                            <label style="display:block;font-size:0.75rem;font-weight:700;color:#475569;margin-bottom:6px;text-transform:uppercase;letter-spacing:0.5px;">Password</label>
                            <div style="position:relative;">
                                <input type="password" id="adminPwdInput" placeholder="Enter password" autofocus
                                    style="width:100%;padding:0.75rem 2.5rem 0.75rem 1rem;border:1.5px solid #cbd5e1;border-radius:8px;font-size:1rem;outline:none;box-sizing:border-box;transition:border-color 0.2s;">
                                <button type="button" id="adminPwdToggleVis" style="position:absolute;right:10px;top:50%;transform:translateY(-50%);background:none;border:none;cursor:pointer;color:#64748b;font-size:1rem;padding:0;">👁️</button>
                            </div>
                            <div id="adminPwdError" style="color:#dc2626;font-size:0.8rem;margin-top:6px;display:none;font-weight:600;">Incorrect password. Admin access denied.</div>
                        </div>
                        <div style="display:flex;gap:0.75rem;justify-content:flex-end;">
                            <button type="button" id="adminPwdCancelBtn" style="background:#f1f5f9;color:#475569;border:1px solid #cbd5e1;padding:0.65rem 1.1rem;border-radius:8px;font-weight:600;cursor:pointer;">Cancel</button>
                            <button type="submit" id="adminPwdSubmitBtn" style="background:#0f766e;color:white;border:none;padding:0.65rem 1.3rem;border-radius:8px;font-weight:700;cursor:pointer;">Unlock Admin</button>
                        </div>
                    </form>
                </div>
            `;
            document.body.appendChild(modal);

            const input = document.getElementById('adminPwdInput');
            const errorDiv = document.getElementById('adminPwdError');
            const form = document.getElementById('adminPasswordForm');
            const cancelBtn = document.getElementById('adminPwdCancelBtn');
            const toggleVis = document.getElementById('adminPwdToggleVis');

            setTimeout(() => input.focus(), 50);

            toggleVis.addEventListener('click', () => {
                if (input.type === 'password') {
                    input.type = 'text';
                    toggleVis.textContent = '🙈';
                } else {
                    input.type = 'password';
                    toggleVis.textContent = '👁️';
                }
            });

            cancelBtn.addEventListener('click', () => {
                modal.remove();
            });

            modal.addEventListener('click', (e) => {
                if (e.target === modal) modal.remove();
            });

            form.addEventListener('submit', (e) => {
                e.preventDefault();
                const entered = (input.value || '').trim();
                if (entered === ADMIN_PASSWORD) {
                    modal.remove();
                    actuallySetRole('admin');
                    if (typeof onSuccess === 'function') {
                        onSuccess();
                    }
                    showRoleToast('👑 Admin mode unlocked successfully', 'success');
                } else {
                    errorDiv.style.display = 'block';
                    input.style.borderColor = '#dc2626';
                    input.focus();
                    input.select();
                }
            });
        }

        function setRole(newRole, onSuccess) {
            const targetRole = (newRole === 'staff') ? 'staff' : 'admin';
            const currentRole = getRole();

            if (targetRole === 'admin' && currentRole === 'staff') {
                promptAdminPassword(() => {
                    if (typeof onSuccess === 'function') onSuccess();
                });
                return;
            }

            actuallySetRole(targetRole);
            if (typeof onSuccess === 'function') {
                onSuccess();
            }
        }

        function renderRoleSwitcher() {
            let roleBox = appSidebar.querySelector('.sidebar-role-container');
            if (!roleBox) {
                roleBox = document.createElement('div');
                roleBox.className = 'sidebar-role-container';
                const nav = appSidebar.querySelector('.sidebar-nav');
                if (nav) {
                    appSidebar.insertBefore(roleBox, nav);
                } else {
                    appSidebar.appendChild(roleBox);
                }
            }
            const current = getRole();
            roleBox.innerHTML = `
                <div class="sidebar-role-label">
                    <span>PORTAL ROLE</span>
                    <span style="opacity:0.85;">${current === 'admin' ? '👑 Dr. Jeswin (Admin)' : '👤 RESTRICTED'}</span>
                </div>
                <div class="sidebar-role-toggle">
                    <button type="button" class="role-btn ${current === 'admin' ? 'active' : ''}" data-role="admin">👑 Admin (Dr. Jeswin)</button>
                    <button type="button" class="role-btn ${current === 'staff' ? 'active' : ''}" data-role="staff">👤 Staff</button>
                </div>
            `;
            roleBox.querySelectorAll('.role-btn').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    e.preventDefault();
                    setRole(btn.getAttribute('data-role'));
                });
            });
        }

        function renderMobileRolePill() {
            const mobileBar = document.querySelector('.mobile-top-bar');
            if (!mobileBar) return;
            let pill = mobileBar.querySelector('.mobile-role-pill');
            if (!pill) {
                pill = document.createElement('button');
                pill.type = 'button';
                pill.className = 'mobile-role-pill';
                const actionLink = mobileBar.querySelector('.mobile-action-link');
                if (actionLink) {
                    mobileBar.insertBefore(pill, actionLink);
                } else {
                    mobileBar.appendChild(pill);
                }
                pill.addEventListener('click', () => {
                    const nextRole = getRole() === 'admin' ? 'staff' : 'admin';
                    setRole(nextRole);
                });
            }
            const role = getRole();
            pill.innerHTML = role === 'admin' ? '👑 Admin (Dr. Jeswin)' : '👤 Staff';
            pill.setAttribute('title', `Active role: ${role}. Click to switch.`);
        }

        function updateAccountsLinkAccess() {
            const role = getRole();
            const accountsLink = appSidebar.querySelector('a[href="accounts.html"]');
            if (accountsLink) {
                let badge = accountsLink.querySelector('.role-lock-badge');
                if (role === 'staff') {
                    accountsLink.classList.add('role-locked');
                    accountsLink.setAttribute('title', 'Admin Only: Restricted for Staff');
                    if (!badge) {
                        badge = document.createElement('span');
                        badge.className = 'role-lock-badge';
                        badge.textContent = '🔒 Admin';
                        accountsLink.appendChild(badge);
                    }
                } else {
                    accountsLink.classList.remove('role-locked');
                    accountsLink.removeAttribute('title');
                    if (badge) badge.remove();
                }
            }
        }

        function showAdminRequiredModal() {
            const existing = document.getElementById('adminRequiredModal');
            if (existing) existing.remove();

            const modal = document.createElement('div');
            modal.id = 'adminRequiredModal';
            modal.style.cssText = 'position:fixed;inset:0;background:rgba(15,23,42,0.6);backdrop-filter:blur(4px);display:flex;align-items:center;justify-content:center;z-index:99999;padding:1rem;';
            modal.innerHTML = `
                <div style="background:white;border-radius:16px;max-width:440px;width:100%;padding:1.75rem;text-align:center;box-shadow:0 20px 25px -5px rgba(0,0,0,0.2);">
                    <div style="width:54px;height:54px;border-radius:50%;background:#fee2e2;color:#dc2626;font-size:1.75rem;display:flex;align-items:center;justify-content:center;margin:0 auto 1rem;">🔒</div>
                    <h3 style="font-size:1.25rem;font-weight:800;color:#0f172a;margin-bottom:0.5rem;">Admin Access Required</h3>
                    <p style="font-size:0.9rem;color:#64748b;line-height:1.5;margin-bottom:1.5rem;">Only clinic administrators (Dr. Jeswin) have the right to view Accounts &amp; Revenue. Your current active role is <strong>Staff</strong>.</p>
                    <div style="display:flex;gap:0.6rem;justify-content:center;">
                        <button type="button" id="modalSwitchAdminBtn" style="background:#0f766e;color:white;border:none;padding:0.65rem 1.25rem;border-radius:8px;font-weight:700;cursor:pointer;">👑 Switch to Admin Mode</button>
                        <button type="button" id="modalCloseAdminBtn" style="background:#f1f5f9;color:#475569;border:1px solid #cbd5e1;padding:0.65rem 1rem;border-radius:8px;font-weight:600;cursor:pointer;">Cancel</button>
                    </div>
                </div>
            `;
            document.body.appendChild(modal);

            document.getElementById('modalSwitchAdminBtn').addEventListener('click', () => {
                modal.remove();
                setRole('admin', () => {
                    window.location.href = 'accounts.html';
                });
            });
            document.getElementById('modalCloseAdminBtn').addEventListener('click', () => {
                modal.remove();
            });
            modal.addEventListener('click', (e) => {
                if (e.target === modal) modal.remove();
            });
        }

        function enforceAccountsPageAccess() {
            const loc = (window.location.pathname || '').toLowerCase();
            if (!loc.includes('accounts.html') && !loc.endsWith('/accounts')) {
                return;
            }
            const role = getRole();
            const container = document.querySelector('.app-main-content .container');
            if (!container) return;

            let restrictedCard = document.getElementById('accountsRestrictedCard');
            const accountsSections = container.querySelectorAll('.accounts-header, .stat-cards-grid, .period-filter-bar, .category-cards-grid, .charts-grid, .payment-modes-card, .ledger-card, .revenue-alert');

            if (role === 'staff') {
                accountsSections.forEach(el => { el.style.display = 'none'; });
                if (!restrictedCard) {
                    restrictedCard = document.createElement('div');
                    restrictedCard.id = 'accountsRestrictedCard';
                    restrictedCard.className = 'admin-restricted-view fade-in';
                    restrictedCard.innerHTML = `
                        <div class="restricted-icon">🔒</div>
                        <h2>Admin Access Restricted</h2>
                        <p>Only clinic administrators (Dr. Jeswin) have the right to view Accounts &amp; Revenue analytics. Your current active role is <strong>Staff</strong>.</p>
                        <div style="display:flex;gap:0.75rem;justify-content:center;flex-wrap:wrap;">
                            <button type="button" id="cardSwitchAdminBtn" style="background:#0f766e;color:white;padding:0.65rem 1.25rem;border-radius:8px;font-weight:700;border:none;cursor:pointer;">
                                👑 Switch to Admin Mode
                            </button>
                            <a href="appointments.html" style="background:#f1f5f9;color:#334155;padding:0.65rem 1.25rem;border-radius:8px;font-weight:600;text-decoration:none;border:1px solid #cbd5e1;display:inline-block;">
                                📅 Go to Appointments
                            </a>
                        </div>
                    `;
                    container.prepend(restrictedCard);
                    document.getElementById('cardSwitchAdminBtn').addEventListener('click', () => {
                        setRole('admin');
                    });
                } else {
                    restrictedCard.style.display = 'block';
                }
            } else {
                if (restrictedCard) restrictedCard.style.display = 'none';
                accountsSections.forEach(el => { el.style.display = ''; });
            }
        }

        function updateDoctorOwnerLabel() {
            const docNameEl = appSidebar.querySelector('.sidebar-doctor-card .doc-name');
            if (docNameEl && (docNameEl.textContent.trim() === 'Attending Doctor' || docNameEl.textContent.trim() === '')) {
                docNameEl.textContent = 'Dr. Jeswin (Owner & Admin)';
            }
        }

        function applyRoleState() {
            renderRoleSwitcher();
            renderMobileRolePill();
            updateAccountsLinkAccess();
            enforceAccountsPageAccess();
            updateDoctorOwnerLabel();
        }

        // Initialize role controller (clean any legacy persistent localStorage role)
        try {
            localStorage.removeItem('dental_user_role');
        } catch (_) {}
        applyRoleState();
        window.addEventListener('storage', (e) => {
            if (e.key === 'dental_user_role') {
                applyRoleState();
            }
        });

        // Close on ESC key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && appSidebar.classList.contains('open')) {
                closeMobileDrawer();
            }
        });

        // Handle window resize cleanly
        let resizeTimer;
        window.addEventListener('resize', () => {
            clearTimeout(resizeTimer);
            resizeTimer = setTimeout(() => {
                if (window.innerWidth > 992 && appSidebar.classList.contains('open')) {
                    closeMobileDrawer();
                }
            }, 100);
        });

        // Expose portal API globally
        window.DentalPortal = {
            getRole,
            setRole,
            isAdmin: () => getRole() === 'admin'
        };
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initSidebar);
    } else {
        initSidebar();
    }
})();
