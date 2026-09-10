<?php

if ( ! defined( 'ABSPATH' ) ) { exit; }

add_action( 'wp_enqueue_scripts', function () {
	if ( is_admin() ) { return; }


	wp_register_script( 'hs-interactions', '', array(), null, true );
	wp_enqueue_script( 'hs-interactions' );
	wp_add_inline_script( 'hs-interactions', "(function(){\n  if (!('IntersectionObserver' in window)) return;\n  if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) return;\n  var SEL = '.wp-block-post-content h2, .wp-block-post-content h3, .wp-block-post-content p,'\n          + '.wp-block-post-content figure, .wp-block-post-content ul, .wp-block-post-content ol,'\n          + '.wp-block-post-content details, .wp-block-post-content table, .wp-block-post-content .wp-block-buttons,'\n          + '.wp-block-post-content .wp-block-columns, .wp-block-post-content .wp-block-quote,'\n          + '.wp-block-post-content .wp-block-separator';\n  var nodes = Array.prototype.slice.call(document.querySelectorAll(SEL));\n  nodes = nodes.filter(function(el){ return !el.closest('.wp-block-cover__inner-container'); });\n  if (!nodes.length) return;\n  nodes.forEach(function(el){\n    el.classList.add('hs-reveal');\n    var sibs = Array.prototype.slice.call(el.parentNode.children).indexOf(el);\n    el.style.transitionDelay = Math.min(sibs, 5) * 70 + 'ms';\n  });\n  var io = new IntersectionObserver(function(entries){\n    entries.forEach(function(e){\n      if (e.isIntersecting){ e.target.classList.add('is-revealed'); io.unobserve(e.target); }\n    });\n  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });\n  nodes.forEach(function(el){ io.observe(el); });\n})();" );
} );
