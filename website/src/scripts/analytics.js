// GA4 Web Analytics for FitMe Marketing Website
// Events: cta_click, section_view, faq_expand

const GA_MEASUREMENT_ID = 'G-XXXXXXXXXX'; // Replace with actual GA4 ID

// Track CTA clicks
function trackCTA(element) {
  const location = element.dataset.cta || 'unknown';
  const type = element.dataset.ctaType || 'app_store';
  if (typeof gtag === 'function') {
    gtag('event', 'cta_click', {
      cta_location: location,
      cta_type: type,
    });
  }
}

// Track section visibility
function trackSections() {
  const sections = document.querySelectorAll('section[id]');
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting && typeof gtag === 'function') {
          gtag('event', 'section_view', {
            section_name: entry.target.id,
          });
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.3 }
  );
  sections.forEach((section) => observer.observe(section));
}

// Track FAQ expansions
function trackFAQ() {
  document.querySelectorAll('details[data-faq-index]').forEach((detail) => {
    detail.addEventListener('toggle', () => {
      if (detail.open && typeof gtag === 'function') {
        gtag('event', 'faq_expand', {
          question_index: parseInt(detail.dataset.faqIndex, 10),
        });
      }
    });
  });
}

// Initialize all tracking
document.addEventListener('DOMContentLoaded', () => {
  // CTA click tracking
  document.querySelectorAll('[data-cta]').forEach((el) => {
    el.addEventListener('click', () => trackCTA(el));
  });

  trackSections();
  trackFAQ();
});

export { GA_MEASUREMENT_ID };
