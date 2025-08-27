export const NoteGraph = {
  mounted() {
    this.initializeChart();
  },

  updated() {
    this.updateChart();
  },

  initializeChart() {
    if (typeof Chart === 'undefined') {
      this.loadChartJS().then(() => {
        this.createChart();
      }).catch((error) => {
        console.error('Failed to load Chart.js:', error);
        this.createSimpleGraph();
      });
      return;
    }
    
    this.createChart();
  },

  loadChartJS() {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdn.jsdelivr.net/npm/chart.js';
      script.onload = resolve;
      script.onerror = reject;
      document.head.appendChild(script);
    });
  },

  createChart() {
    const canvas = this.el.querySelector('#note-graph-canvas');
    if (!canvas) {
      console.error('Canvas element not found');
      return;
    }

    const ctx = canvas.getContext('2d');
    const data = this.getChartData();
    const voteOptions = this.getVoteOptions();
    const minValue = Math.min(...voteOptions.map(Number));
    const maxValue = Math.max(...voteOptions.map(Number));

    try {
      this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        datasets: [{
          label: 'Rolling Average',
          data: data.labels.map((minute, index) => ({
            x: minute,
            y: data.values[index]
          })),
          borderColor: 'rgb(168, 85, 247)',
          backgroundColor: 'rgba(168, 85, 247, 0.3)',
          borderWidth: 2,
          fill: true,
          tension: 0.4,
          pointBackgroundColor: 'rgb(168, 85, 247)',
          pointBorderColor: '#ffffff',
          pointBorderWidth: 2,
          pointRadius: 3,
          pointHoverRadius: 5
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: {
          padding: {
            left: 10,
            right: 10,
            top: 10,
            bottom: 5
          }
        },
        plugins: {
          legend: {
            display: false  // Using custom HTML legend instead
          },
          tooltip: {
            backgroundColor: 'rgba(55, 65, 81, 0.95)', // gray-700 - lighter than pure black
            titleColor: '#F3F4F6', // gray-100
            bodyColor: '#E5E7EB', // gray-200
            borderColor: 'rgb(168, 85, 247)',
            borderWidth: 1,
            cornerRadius: 8,
            displayColors: false,
            callbacks: {
              title: function(context) {
                return `Time: ${context[0].label}`;
              },
              label: function(context) {
                return `Average Score: ${context.parsed.y}`;
              }
            }
          }
        },
        scales: {
          x: {
            type: 'linear',
            position: 'bottom',
            min: data.labels.length > 0 ? Math.min(0, Math.min(...data.labels) - 0.5) : -0.5,
            max: data.labels.length > 0 ? Math.max(...data.labels) + 0.5 : 10.5,
            title: {
              display: false
            },
            grid: {
              color: 'rgba(156, 163, 175, 0.3)',
              lineWidth: 1
            },
            ticks: {
              color: '#D1D5DB',
              maxTicksLimit: 10,
              stepSize: 1,
              callback: function(value) {
                return Math.round(value) + 'm';
              }
            }
          },
          y: {
            beginAtZero: false,
            min: minValue,
            max: maxValue,
            ticks: {
              stepSize: 1,
              color: '#D1D5DB', // gray-300 - lighter for dark background
              callback: function(value) {
                // Only show ticks that are in the vote options
                return voteOptions.includes(value.toString()) ? value.toString() : '';
              }
            },
            grid: {
              color: 'rgba(156, 163, 175, 0.3)', // lighter gray for dark background
              lineWidth: 1
            }
          }
        },
        interaction: {
          intersect: false,
          mode: 'index'
        },
        animation: {
          duration: 750,
          easing: 'easeInOutQuart'
        }
      }
    });
    
    } catch (error) {
      console.error('Error creating Chart.js chart:', error);
      this.createSimpleGraph();
    }
    
    // Ensure proper sizing without flickering
    if (this.chart) {
      requestAnimationFrame(() => {
        this.chart.resize();
      });
    }
  },

  updateChart() {
    if (!this.chart) {
      this.initializeChart();
      return;
    }

    const data = this.getChartData();
    this.chart.data.datasets[0].data = data.labels.map((minute, index) => ({
      x: minute,
      y: data.values[index]
    }));
    
    // Update X-axis bounds to prevent clipping
    if (data.labels.length > 0) {
      this.chart.options.scales.x.min = Math.min(0, Math.min(...data.labels) - 0.5);
      this.chart.options.scales.x.max = Math.max(...data.labels) + 0.5;
    }
    
    this.chart.update('none'); // No animation on update
    
    // Maintain proper size on update without flickering
    requestAnimationFrame(() => {
      if (this.chart) {
        this.chart.resize();
      }
    });
  },

  getChartData() {
    // Get data from the element's dataset
    const rawData = this.el.dataset.voteData;
    const rawSessionStart = this.el.dataset.sessionStart;
    
    if (!rawData || !rawSessionStart) {
      return { labels: [], values: [] };
    }

    try {
      const voteData = JSON.parse(rawData);
      const sessionStartString = JSON.parse(rawSessionStart);
      const sessionStart = new Date(sessionStartString);
      
      // Handle empty vote data
      if (voteData.length === 0) {
        return { labels: [], values: [] };
      }
      
      // Use the earliest vote time as reference point if session start is after first vote
      const firstVoteTime = new Date(voteData[0][0]);
      const referenceTime = firstVoteTime.getTime() < sessionStart.getTime() ? firstVoteTime : sessionStart;
      
      // Calculate elapsed minutes from reference point
      const labels = voteData.map(([timestamp, _]) => {
        const dataTime = new Date(timestamp);
        const elapsedMs = dataTime.getTime() - referenceTime.getTime();
        const elapsedMinutes = Math.round(elapsedMs / (1000 * 60));
        return Math.max(0, elapsedMinutes); // Ensure non-negative
      });
      
      const values = voteData.map(([_, avg]) => avg);
      
      return { labels, values };
    } catch (error) {
      console.error('Error parsing vote data:', error);
      return { labels: [], values: [] };
    }
  },

  getVoteOptions() {
    const rawOptions = this.el.dataset.voteOptions;
    if (!rawOptions) {
      return ['1', '2', '3', '4', '5']; // fallback
    }

    try {
      const options = JSON.parse(rawOptions);
      return options.filter(opt => opt !== 'smash' && opt !== 'pass'); // filter out non-numeric options
    } catch (error) {
      console.error('Error parsing vote options:', error);
      return ['1', '2', '3', '4', '5']; // fallback
    }
  },

  createSimpleGraph() {
    const canvas = this.el.querySelector('#note-graph-canvas');
    if (!canvas) return;

    const data = this.getChartData();
    const voteOptions = this.getVoteOptions();
    if (data.values.length === 0) return;

    // Hide canvas and create SVG instead
    canvas.style.display = 'none';
    
    // Create simple SVG line chart with proper ticks
    const svgContainer = document.createElement('div');
    svgContainer.innerHTML = `
      <svg width="100%" height="150" viewBox="0 0 800 150" style="background: transparent;">
        <defs>
          <linearGradient id="lineGradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" style="stop-color:rgb(168,85,247);stop-opacity:1" />
            <stop offset="100%" style="stop-color:rgb(236,72,153);stop-opacity:1" />
          </linearGradient>
        </defs>
        <g>
          <!-- Y-axis ticks and labels -->
          ${this.createYAxisTicks(voteOptions)}
          <!-- X-axis grid and labels -->
          ${this.createXAxisGrid(data.labels)}
          <!-- Data line -->
          ${this.createSimplePath(data.values, data.labels, voteOptions)}
        </g>
      </svg>
    `;
    
    canvas.parentNode.appendChild(svgContainer);
  },

  createYAxisTicks(voteOptions) {
    const height = 150;
    const padding = 20;
    let ticks = '';
    
    const minValue = Math.min(...voteOptions.map(Number));
    const maxValue = Math.max(...voteOptions.map(Number));
    const range = maxValue - minValue;
    
    // Create ticks for each vote option
    voteOptions.forEach(option => {
      const value = Number(option);
      const y = height - padding - ((value - minValue) / range) * (height - 2 * padding);
      ticks += `
        <line x1="40" y1="${y}" x2="760" y2="${y}" stroke="rgba(156,163,175,0.3)" stroke-width="1"/>
        <text x="30" y="${y + 4}" fill="#D1D5DB" font-size="10" text-anchor="end">${option}</text>
      `;
    });
    
    return ticks;
  },

  createXAxisGrid(minuteLabels) {
    if (minuteLabels.length === 0) return '';
    
    const width = 720; // 760 - 40 (left padding)
    const padding = 40;
    let grid = '';
    
    const minMinute = Math.min(...minuteLabels);
    const maxMinute = Math.max(...minuteLabels);
    const minuteRange = maxMinute - minMinute || 1;
    
    // Create vertical grid lines and labels for minute markers
    const step = Math.max(1, Math.floor(minuteLabels.length / 8)); // Show max 8 vertical lines
    for (let i = 0; i < minuteLabels.length; i += step) {
      const minute = minuteLabels[i];
      const x = padding + ((minute - minMinute) / minuteRange) * width;
      grid += `
        <line x1="${x}" y1="20" x2="${x}" y2="130" stroke="rgba(156,163,175,0.2)" stroke-width="1"/>
        <text x="${x}" y="145" fill="#D1D5DB" font-size="10" text-anchor="middle">${minute}m</text>
      `;
    }
    
    return grid;
  },

  createSimplePath(values, minuteLabels, voteOptions) {
    if (values.length === 0 || minuteLabels.length === 0) return '';
    
    const width = 720; // 760 - 40 (left padding)
    const height = 110; // 130 - 20 (top/bottom padding)
    const padding = 40;
    
    // Use actual vote options range for Y-axis
    const minVoteValue = Math.min(...voteOptions.map(Number));
    const maxVoteValue = Math.max(...voteOptions.map(Number));
    const voteRange = maxVoteValue - minVoteValue || 1;
    
    // Use minute range for X-axis
    const minMinute = Math.min(...minuteLabels);
    const maxMinute = Math.max(...minuteLabels);
    const minuteRange = maxMinute - minMinute || 1;
    
    let path = '';
    values.forEach((value, index) => {
      const minute = minuteLabels[index];
      const x = padding + ((minute - minMinute) / minuteRange) * width;
      const y = 130 - ((value - minVoteValue) / voteRange) * height; // Flip Y coordinate
      
      if (index === 0) {
        path += `M ${x} ${y}`;
      } else {
        path += ` L ${x} ${y}`;
      }
    });
    
    return `<path d="${path}" stroke="url(#lineGradient)" stroke-width="2" fill="none"/>`;
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
      this.chart = null;
    }
  }
};