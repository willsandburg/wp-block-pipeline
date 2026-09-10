<?php
/**
 * Plugin Name: Highland Sites
 * Description: The Highland Sites pipeline's site-side plugin. Provides the
 *              contact form block (dynamic, so it can never fail validation)
 *              and the presentation behaviour that global styles cannot express
 *              - scroll-triggered reveals, nav underline, card and hero styling.
 *              Everything respects prefers-reduced-motion, and the reveal hides
 *              nothing unless JavaScript actually runs.
 * Version: 1.0.0
 * Author: Will Sandburg
 * Requires at least: 6.7
 * Requires PHP: 7.4
 */

if ( ! defined( 'ABSPATH' ) ) { exit; }

require_once __DIR__ . '/includes/form.php';
require_once __DIR__ . '/includes/interactions.php';
