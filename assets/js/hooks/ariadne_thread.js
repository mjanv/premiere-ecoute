function circleMetrics(id, containerTop) {
  const el = document.getElementById(id);
  if (!el) return null;
  const rect = el.getBoundingClientRect();
  return {
    top: rect.top - containerTop,
    center: rect.top + rect.height / 2 - containerTop,
  };
}

function updateCircles(progressThread, origin, containerTop) {
  const threadBottom = origin + (parseFloat(getComputedStyle(progressThread).height) || 0);
  [1, 2, 3, 4].forEach(n => {
    const circle = document.getElementById('step-circle-' + n);
    if (!circle) return;
    const rect = circle.getBoundingClientRect();
    const mid = rect.top + rect.height / 2 - containerTop;
    if (threadBottom >= mid - 1) {
      circle.classList.add('step-circle-active');
    } else {
      circle.classList.remove('step-circle-active');
    }
  });
}

function runUpdate(container) {
  const baseThread = container.querySelector('.ariane-thread-base');
  const progressThread = container.querySelector('.ariane-thread-progress');
  if (!progressThread) return;

  const progressStep = progressThread.getAttribute('data-progress-step');
  const containerTop = container.getBoundingClientRect().top;

  const c1 = circleMetrics('step-circle-1', containerTop);
  if (!c1) return;
  const origin = c1.center;

  const heightTo = (id) => {
    const m = circleMetrics(id, containerTop);
    return m ? Math.max(0, m.center - origin) : 0;
  };

  const lastCircleId = progressStep === '4' ? 'step-circle-4'
    : progressStep === '3' ? 'step-circle-3'
    : progressStep === '2' ? 'step-circle-2'
    : 'step-circle-1';

  if (baseThread) {
    baseThread.style.top = origin + 'px';
    baseThread.style.height = (heightTo(lastCircleId) || 0) + 'px';
  }

  progressThread.style.top = origin + 'px';

  const progressHeight = heightTo(lastCircleId);
  const prevHeight = parseFloat(progressThread.style.height) || 0;
  progressThread.style.height = progressHeight + 'px';

  if (prevHeight === progressHeight) {
    updateCircles(progressThread, origin, containerTop);
  } else {
    const poll = () => {
      updateCircles(progressThread, origin, containerTop);
      const current = parseFloat(getComputedStyle(progressThread).height) || 0;
      if (Math.abs(current - progressHeight) > 1) {
        requestAnimationFrame(poll);
      } else {
        updateCircles(progressThread, origin, containerTop);
      }
    };
    requestAnimationFrame(poll);
  }
}

export const AriadneThread = {
  mounted() {
    this.update = () => runUpdate(this.el);

    // Retry until step-circle-1 has non-zero dimensions — handles LiveView navigation
    // where the DOM is patched but layout may not be complete yet.
    let retries = 0;
    const tryUpdate = () => {
      const c1 = document.getElementById('step-circle-1');
      if (c1 && c1.getBoundingClientRect().height > 0) {
        this.update();
      } else if (retries < 20) {
        retries++;
        requestAnimationFrame(tryUpdate);
      }
    };
    requestAnimationFrame(tryUpdate);

    document.addEventListener('phx:update', this.update);
    window.addEventListener('resize', this.update);
  },

  updated() {
    this.update();
  },

  destroyed() {
    document.removeEventListener('phx:update', this.update);
    window.removeEventListener('resize', this.update);
  }
};
