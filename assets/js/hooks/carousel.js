export const Carousel = {
  mounted() {
    this.initializeCarousel();
  },

  updated() {
    this.initializeCarousel();
  },

  updateScores(slideIndex) {
    const viewerScoreEl = document.getElementById('viewer-score');
    const streamerScoreEl = document.getElementById('streamer-score');
    const titleEl = document.getElementById('carousel-title');
    const subtitleEl = document.getElementById('carousel-subtitle');
    const mostLikedBadgeEl = document.getElementById('most-liked-badge');
    const leastLikedBadgeEl = document.getElementById('least-liked-badge');
    
    if (!viewerScoreEl || !streamerScoreEl || !titleEl) return;

    if (slideIndex === 0) {
      // Overall scores - use session averages, album name, and artist
      viewerScoreEl.textContent = this.el.dataset.sessionViewerScore || '—';
      streamerScoreEl.textContent = this.el.dataset.sessionStreamerScore || '—';
      titleEl.textContent = this.el.dataset.albumNameOnly || 'Album';
      if (subtitleEl) {
        subtitleEl.textContent = this.el.dataset.albumArtist || '';
        subtitleEl.style.display = 'block';
      }
      // Hide both badges for overall session view
      if (mostLikedBadgeEl) {
        mostLikedBadgeEl.style.opacity = '0';
      }
      if (leastLikedBadgeEl) {
        leastLikedBadgeEl.style.opacity = '0';
      }
    } else {
      // Individual track scores and name
      const trackIndex = slideIndex - 1;
      const trackName = this.el.dataset[`track${trackIndex}Name`];

      viewerScoreEl.textContent = this.el.dataset[`track${trackIndex}ViewerScore`] || '—';
      streamerScoreEl.textContent = this.el.dataset[`track${trackIndex}StreamerScore`] || '—';
      titleEl.textContent = trackName || `Track ${trackIndex + 1}`;
      if (subtitleEl) {
        subtitleEl.style.display = 'none';
      }
      
      // Show/hide badges based on current track
      const mostLikedTrackId = this.el.dataset.mostLikedTrack;
      const leastLikedTrackId = this.el.dataset.leastLikedTrack;
      const currentTrackId = this.getCurrentTrackId(trackIndex);
      
      // Handle most liked badge
      if (mostLikedBadgeEl && mostLikedTrackId) {
        if (currentTrackId === mostLikedTrackId) {
          mostLikedBadgeEl.style.opacity = '1';
        } else {
          mostLikedBadgeEl.style.opacity = '0';
        }
      }
      
      // Handle least liked badge
      if (leastLikedBadgeEl && leastLikedTrackId) {
        if (currentTrackId === leastLikedTrackId) {
          leastLikedBadgeEl.style.opacity = '1';
        } else {
          leastLikedBadgeEl.style.opacity = '0';
        }
      }
    }
  },

  getCurrentTrackId(trackIndex) {
    return this.el.dataset[`track${trackIndex}Id`];
  },

  initializeCarousel() {
    const container = this.el.querySelector('#carousel-container');
    const prevButton = this.el.querySelector('#carousel-prev');
    const nextButton = this.el.querySelector('#carousel-next');
    const dots = this.el.querySelectorAll('.carousel-dot');
    
    if (!container || !prevButton || !nextButton) return;
    
    let currentIndex = 0;
    const totalSlides = container.children.length;
    
    // Remove existing event listeners to prevent duplicates
    if (this.prevHandler) prevButton.removeEventListener('click', this.prevHandler);
    if (this.nextHandler) nextButton.removeEventListener('click', this.nextHandler);
    if (this.dotHandlers) {
      this.dotHandlers.forEach((handler, index) => {
        dots[index]?.removeEventListener('click', handler);
      });
    }
    
    const updateCarousel = () => {
      const translateX = -currentIndex * 100;
      container.style.transform = `translateX(${translateX}%)`;
      
      // Update dots
      dots.forEach((dot, index) => {
        if (index === currentIndex) {
          dot.classList.remove('bg-white/30');
          dot.classList.add('bg-white/60');
        } else {
          dot.classList.remove('bg-white/60');
          dot.classList.add('bg-white/30');
        }
      });

      // Update scores based on current slide
      this.updateScores(currentIndex);
    };
    
    const nextSlide = () => {
      currentIndex = (currentIndex + 1) % totalSlides;
      updateCarousel();
    };
    
    const prevSlide = () => {
      currentIndex = (currentIndex - 1 + totalSlides) % totalSlides;
      updateCarousel();
    };
    
    // Store handlers for cleanup
    this.nextHandler = nextSlide;
    this.prevHandler = prevSlide;
    this.dotHandlers = [];
    
    nextButton.addEventListener('click', this.nextHandler);
    prevButton.addEventListener('click', this.prevHandler);
    
    // Dot navigation
    dots.forEach((dot, index) => {
      const handler = () => {
        currentIndex = index;
        updateCarousel();
      };
      this.dotHandlers.push(handler);
      dot.addEventListener('click', handler);
    });
    
    // Initialize first state
    updateCarousel();
  },

  destroyed() {
    // Cleanup event listeners
    const prevButton = this.el.querySelector('#carousel-prev');
    const nextButton = this.el.querySelector('#carousel-next');
    const dots = this.el.querySelectorAll('.carousel-dot');
    
    if (this.prevHandler) prevButton?.removeEventListener('click', this.prevHandler);
    if (this.nextHandler) nextButton?.removeEventListener('click', this.nextHandler);
    if (this.dotHandlers) {
      this.dotHandlers.forEach((handler, index) => {
        dots[index]?.removeEventListener('click', handler);
      });
    }
  }
};