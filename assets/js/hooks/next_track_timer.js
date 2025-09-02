export const NextTrackTimer = {
  mounted() {
    this.nextTrackAt = new Date(this.el.dataset.nextTrackAt);
    this.timerDisplay = this.el.querySelector('#timer-display');
    
    // Update timer immediately
    this.updateTimer();
    
    // Update every second
    this.intervalId = setInterval(() => {
      this.updateTimer();
    }, 1000);
  },

  updated() {
    // Handle updates to the next_track_at value
    const newNextTrackAt = new Date(this.el.dataset.nextTrackAt);
    if (newNextTrackAt.getTime() !== this.nextTrackAt.getTime()) {
      this.nextTrackAt = newNextTrackAt;
      this.updateTimer();
    }
  },

  destroyed() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  },

  updateTimer() {
    const now = new Date();
    const timeDiff = this.nextTrackAt.getTime() - now.getTime();
    
    if (timeDiff <= 0) {
      // Timer expired
      this.timerDisplay.textContent = "00:00";
      if (this.intervalId) {
        clearInterval(this.intervalId);
        this.intervalId = null;
      }
      return;
    }
    
    // Calculate minutes and seconds
    const totalSeconds = Math.floor(timeDiff / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    
    // Format as MM:SS
    const formattedTime = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    this.timerDisplay.textContent = formattedTime;
  }
};