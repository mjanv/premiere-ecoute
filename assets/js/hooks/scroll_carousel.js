export const ScrollCarousel = {
  mounted() {
    const track = this.el.querySelector("[data-carousel-track]");
    const prev = this.el.querySelector("[data-carousel-prev]");
    const next = this.el.querySelector("[data-carousel-next]");

    if (!track || !prev || !next) return;

    const scroll = (dir) => {
      const itemWidth = track.querySelector(":scope > *")?.offsetWidth ?? 160;
      track.scrollBy({ left: dir * (itemWidth + 16), behavior: "smooth" });
    };

    const sync = () => {
      const atStart = track.scrollLeft <= 0;
      const atEnd = track.scrollLeft + track.clientWidth >= track.scrollWidth - 1;
      prev.classList.toggle("opacity-0", atStart);
      prev.classList.toggle("pointer-events-none", atStart);
      next.classList.toggle("opacity-0", atEnd);
      next.classList.toggle("pointer-events-none", atEnd);
    };

    this.prevHandler = () => scroll(-1);
    this.nextHandler = () => scroll(1);
    this.scrollHandler = sync;

    prev.addEventListener("click", this.prevHandler);
    next.addEventListener("click", this.nextHandler);
    track.addEventListener("scroll", this.scrollHandler);

    sync();
  },

  destroyed() {
    const track = this.el.querySelector("[data-carousel-track]");
    const prev = this.el.querySelector("[data-carousel-prev]");
    const next = this.el.querySelector("[data-carousel-next]");

    prev?.removeEventListener("click", this.prevHandler);
    next?.removeEventListener("click", this.nextHandler);
    track?.removeEventListener("scroll", this.scrollHandler);
  }
};
