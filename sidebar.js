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
            link.addEventListener('click', () => {
                if (window.innerWidth <= 992) {
                    closeMobileDrawer();
                }
            });
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
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initSidebar);
    } else {
        initSidebar();
    }
})();
