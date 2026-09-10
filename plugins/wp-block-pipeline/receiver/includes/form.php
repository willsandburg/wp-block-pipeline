<?php

if ( ! defined( 'ABSPATH' ) ) { exit; }

const HS_FORM_CPT = 'hs_submission';

/* ------------------------------------------------------------------ storage */

add_action( 'init', function () {
	register_post_type( HS_FORM_CPT, array(
		'labels'       => array( 'name' => 'Form submissions', 'singular_name' => 'Submission' ),
		'public'       => false,
		'show_ui'      => true,
		'show_in_menu' => true,
		'menu_icon'    => 'dashicons-email-alt',
		'capability_type' => 'post',
		'capabilities' => array( 'create_posts' => 'do_not_allow' ),
		'map_meta_cap' => true,
		'supports'     => array( 'title', 'editor', 'custom-fields' ),
		'show_in_rest' => true,
		'rest_base'    => 'hs-submissions',
	) );
} );

/* ------------------------------------------------------------------- block */

add_action( 'init', function () {
	register_block_type( 'highlandsites/form', array(
		'api_version' => 3,
		'title'       => 'Contact form',
		'category'    => 'widgets',
		'icon'        => 'email-alt',
		'description' => 'A short contact form. Submissions are stored and emailed.',
		'attributes'  => array(
			'formId'         => array( 'type' => 'string', 'default' => 'contact' ),
			'submitLabel'    => array( 'type' => 'string', 'default' => 'Send' ),
			'successMessage' => array( 'type' => 'string', 'default' => 'Thanks - I will come back to you.' ),
			'recipient'      => array( 'type' => 'string', 'default' => '' ),
		),
		'supports'        => array( 'html' => false, 'align' => array( 'wide' ) ),
		'render_callback' => 'hs_form_render',
	) );
} );

function hs_form_render( $attrs ) {
	$label   = isset( $attrs['submitLabel'] ) ? $attrs['submitLabel'] : 'Send';
	$form_id = isset( $attrs['formId'] ) ? sanitize_key( $attrs['formId'] ) : 'contact';
	$ok_msg  = isset( $attrs['successMessage'] ) ? $attrs['successMessage'] : 'Thanks.';
	$notice  = '';

	if ( isset( $_GET['hs_sent'] ) && $_GET['hs_sent'] === $form_id ) {
		$notice = '<p class="hs-form__notice hs-form__notice--ok" role="status">'
			. esc_html( $ok_msg ) . '</p>';
	} elseif ( isset( $_GET['hs_error'] ) ) {
		$notice = '<p class="hs-form__notice hs-form__notice--error" role="alert">'
			. esc_html( hs_form_error_text( sanitize_key( wp_unslash( $_GET['hs_error'] ) ) ) ) . '</p>';
	}

	$fields = array(
		array( 'name', 'Name',  'text',     true  ),
		array( 'email','Email', 'email',    true  ),
		array( 'message','Message','textarea', true ),
	);

	$html  = '<div class="wp-block-highlandsites-form hs-form" data-form-id="' . esc_attr( $form_id ) . '">';
	$html .= $notice;
	$html .= '<form method="post" action="' . esc_url( admin_url( 'admin-post.php' ) ) . '">';
	$html .= '<input type="hidden" name="action" value="hs_form_submit" />';
	$html .= '<input type="hidden" name="hs_form_id" value="' . esc_attr( $form_id ) . '" />';
	$html .= '<input type="hidden" name="hs_return" value="' . esc_url( home_url( add_query_arg( array() ) ) ) . '" />';
	$html .= '<input type="hidden" name="hs_t" value="' . esc_attr( time() ) . '" />';
	$html .= wp_nonce_field( 'hs_form_' . $form_id, 'hs_nonce', true, false );
	// honeypot - hidden from people, tempting to bots
	$html .= '<div class="hs-form__hp" aria-hidden="true">'
		. '<label>Leave this empty<input type="text" name="hs_website" tabindex="-1" autocomplete="off" /></label></div>';

	foreach ( $fields as list( $key, $lbl, $type, $req ) ) {
		$id = 'hs-' . $form_id . '-' . $key;
		$html .= '<p class="hs-form__row">';
		$html .= '<label class="hs-form__label" for="' . esc_attr( $id ) . '">' . esc_html( $lbl )
			. ( $req ? ' <span class="hs-form__req" aria-hidden="true">*</span>' : '' ) . '</label>';
		if ( $type === 'textarea' ) {
			$html .= '<textarea class="hs-form__input" id="' . esc_attr( $id ) . '" name="hs_' . esc_attr( $key )
				. '" rows="6"' . ( $req ? ' required' : '' ) . '></textarea>';
		} else {
			$html .= '<input class="hs-form__input" id="' . esc_attr( $id ) . '" type="' . esc_attr( $type )
				. '" name="hs_' . esc_attr( $key ) . '"' . ( $req ? ' required' : '' ) . ' />';
		}
		$html .= '</p>';
	}

	$html .= '<p class="hs-form__actions"><button type="submit" class="wp-element-button hs-form__submit">'
		. esc_html( $label ) . '</button></p>';
	$html .= '</form></div>';
	return $html;
}

function hs_form_error_text( $code ) {
	switch ( $code ) {
		case 'required': return 'Please fill in every field.';
		case 'email':    return 'That email address does not look right.';
		case 'nonce':    return 'That form expired. Please try again.';
		case 'rate':     return 'That went through already, or too quickly. Give it a minute.';
		default:         return 'Something went wrong. Please try again.';
	}
}

/* -------------------------------------------------------------- submission */

function hs_form_handle() {
	$form_id = isset( $_POST['hs_form_id'] ) ? sanitize_key( wp_unslash( $_POST['hs_form_id'] ) ) : 'contact';
	$return  = isset( $_POST['hs_return'] ) ? esc_url_raw( wp_unslash( $_POST['hs_return'] ) ) : home_url( '/' );
	$bounce  = function ( $args ) use ( $return ) {
		wp_safe_redirect( add_query_arg( $args, $return ) ); exit;
	};

	if ( ! isset( $_POST['hs_nonce'] ) || ! wp_verify_nonce( wp_unslash( $_POST['hs_nonce'] ), 'hs_form_' . $form_id ) ) {
		$bounce( array( 'hs_error' => 'nonce' ) );
	}
	// honeypot filled, or submitted within 3 seconds of render: a bot
	if ( ! empty( $_POST['hs_website'] ) ) { $bounce( array( 'hs_error' => 'rate' ) ); }
	$t = isset( $_POST['hs_t'] ) ? absint( $_POST['hs_t'] ) : 0;
	if ( $t && ( time() - $t ) < 3 ) { $bounce( array( 'hs_error' => 'rate' ) ); }

	$ip  = isset( $_SERVER['REMOTE_ADDR'] ) ? sanitize_text_field( wp_unslash( $_SERVER['REMOTE_ADDR'] ) ) : '0';
	$key = 'hs_form_' . md5( $ip . '|' . $form_id );
	if ( get_transient( $key ) ) { $bounce( array( 'hs_error' => 'rate' ) ); }

	$name      = isset( $_POST['hs_name'] ) ? sanitize_text_field( wp_unslash( $_POST['hs_name'] ) ) : '';
	$raw_email = isset( $_POST['hs_email'] ) ? trim( wp_unslash( $_POST['hs_email'] ) ) : '';
	$email     = sanitize_email( $raw_email );
	$message   = isset( $_POST['hs_message'] ) ? sanitize_textarea_field( wp_unslash( $_POST['hs_message'] ) ) : '';

	// check emptiness on what was actually typed, so a malformed address reports
	// as a bad address rather than as a missing field
	if ( $name === '' || $raw_email === '' || $message === '' ) { $bounce( array( 'hs_error' => 'required' ) ); }
	if ( $email === '' || ! is_email( $email ) ) { $bounce( array( 'hs_error' => 'email' ) ); }

	set_transient( $key, 1, MINUTE_IN_SECONDS );

	$post_id = wp_insert_post( array(
		'post_type'    => HS_FORM_CPT,
		'post_status'  => 'private',
		// angle brackets are stripped by wp_insert_post, so the address goes in parens
		'post_title'   => sprintf( '%s (%s)', $name, $email ),
		'post_content' => $message,
	) );
	if ( $post_id && ! is_wp_error( $post_id ) ) {
		update_post_meta( $post_id, 'hs_email', $email );
		update_post_meta( $post_id, 'hs_form_id', $form_id );
	}

	// Capture why delivery failed instead of losing it. A form that silently
	// stops emailing is the most common way enquiries disappear, and the host
	// is usually the cause, not the form.
	$mail_error = '';
	$catch = function ( $wp_error ) use ( &$mail_error ) {
		$mail_error = $wp_error->get_error_message();
	};
	add_action( 'wp_mail_failed', $catch );

	$to     = get_option( 'admin_email' );
	$domain = wp_parse_url( home_url(), PHP_URL_HOST );
	$domain = preg_replace( '/^www\./', '', (string) $domain );

	$sent = wp_mail(
		$to,
		sprintf( '[%s] New enquiry from %s', get_bloginfo( 'name' ), $name ),
		sprintf( "From: %s <%s>\n\n%s\n", $name, $email, $message ),
		array(
			// An explicit From on the site's own domain. The default
			// wordpress@ address fails SPF alignment on some hosts.
			'From: ' . get_bloginfo( 'name' ) . ' <noreply@' . $domain . '>',
			'Reply-To: ' . $name . ' <' . $email . '>',
		)
	);
	remove_action( 'wp_mail_failed', $catch );

	if ( $post_id && ! is_wp_error( $post_id ) ) {
		update_post_meta( $post_id, 'hs_mail_sent', $sent ? '1' : '0' );
		if ( ! $sent ) {
			update_post_meta( $post_id, 'hs_mail_error', $mail_error ?: 'wp_mail returned false with no error' );
			set_transient( 'hs_mail_last_error', $mail_error ?: 'wp_mail returned false', DAY_IN_SECONDS );
		}
	}

	$bounce( array( 'hs_sent' => $form_id ) );
}
add_action( 'admin_post_nopriv_hs_form_submit', 'hs_form_handle' );
add_action( 'admin_post_hs_form_submit', 'hs_form_handle' );

/* ------------------------------------------------------------ admin notice */

add_action( 'admin_notices', function () {
	$err = get_transient( 'hs_mail_last_error' );
	if ( ! $err || ! current_user_can( 'manage_options' ) ) { return; }
	printf(
		'<div class="notice notice-warning is-dismissible"><p><strong>Highland Sites:</strong> '
		. 'a form submission was saved but the email did not send. Every submission is still '
		. 'stored under Form submissions, so nothing was lost.</p><p><code>%s</code></p>'
		. '<p>This is almost always the host rather than the form. An SMTP plugin pointed at a '
		. 'real mailbox fixes it.</p></div>',
		esc_html( $err )
	);
} );

/* ------------------------------------------------------------------ styles */

add_action( 'wp_enqueue_scripts', function () {
	$css = '.hs-form{max-width:34rem;margin-inline:auto;text-align:left}'
		. '.hs-form__hp{position:absolute;left:-9999px;width:1px;height:1px;overflow:hidden}'
		. '.hs-form__row{display:flex;flex-direction:column;gap:.4rem;margin:0 0 1.1rem}'
		. '.hs-form__label{font-size:.85rem;font-weight:600;'
		. 'color:var(--wp--preset--color--secondary)}'
		. '.hs-form__req{color:var(--wp--preset--color--accent)}'
		. '.hs-form__input{width:100%;padding:.7rem .85rem;border-radius:8px;'
		. 'border:1px solid color-mix(in srgb,var(--wp--preset--color--primary) 22%,transparent);'
		. 'background:var(--wp--preset--color--base);color:var(--wp--preset--color--contrast);'
		. 'font:inherit;transition:border-color .2s ease,box-shadow .2s ease}'
		. '.hs-form__input:focus{outline:none;border-color:var(--wp--preset--color--primary);'
		. 'box-shadow:0 0 0 3px color-mix(in srgb,var(--wp--preset--color--primary) 18%,transparent)}'
		. '.hs-form__actions{margin:0}'
		. '.hs-form__submit{cursor:pointer;border:0}'
		. '.hs-form__notice{padding:.8rem 1rem;border-radius:8px;margin:0 0 1.2rem;font-size:.95rem}'
		. '.hs-form__notice--ok{background:color-mix(in srgb,var(--wp--preset--color--primary) 12%,transparent);'
		. 'color:var(--wp--preset--color--primary)}'
		. '.hs-form__notice--error{background:color-mix(in srgb,var(--wp--preset--color--accent) 14%,transparent);'
		. 'color:var(--wp--preset--color--accent)}';
	wp_register_style( 'hs-form', false, array(), null );
	wp_enqueue_style( 'hs-form' );
	wp_add_inline_style( 'hs-form', $css );
} );

/* ------------------------------------------------------- editor registration */

add_action( 'enqueue_block_editor_assets', function () {
	$js = <<<'JS'
( function ( blocks, el, blockEditor, components, i18n ) {
	blocks.registerBlockType( 'highlandsites/form', {
		edit: function ( props ) {
			var bp = blockEditor.useBlockProps();
			return el( 'div', bp,
				el( blockEditor.InspectorControls, {},
					el( components.PanelBody, { title: 'Form' },
						el( components.TextControl, {
							label: 'Submit button label',
							value: props.attributes.submitLabel,
							onChange: function ( v ) { props.setAttributes( { submitLabel: v } ); }
						} ),
						el( components.TextControl, {
							label: 'Message after sending',
							value: props.attributes.successMessage,
							onChange: function ( v ) { props.setAttributes( { successMessage: v } ); }
						} )
					)
				),
				el( 'div', { className: 'hs-form-preview', style: {
						border: '1px dashed #b7c0c7', borderRadius: '10px', padding: '1.25rem'
					} },
					el( 'p', { style: { margin: '0 0 .75rem', fontWeight: 600 } }, 'Contact form' ),
					el( 'p', { style: { margin: 0, fontSize: '.9rem', color: '#4E6672' } },
						'Name, Email and Message, with a "' + props.attributes.submitLabel + '" button. '
						+ 'Submissions are saved under Form submissions and emailed to the site admin.' )
				)
			);
		},
		save: function () { return null; }
	} );
} )( window.wp.blocks, window.wp.element.createElement, window.wp.blockEditor,
     window.wp.components, window.wp.i18n );
JS;
	wp_register_script( 'hs-form-editor', '', array( 'wp-blocks', 'wp-element', 'wp-block-editor', 'wp-components' ), null, true );
	wp_enqueue_script( 'hs-form-editor' );
	wp_add_inline_script( 'hs-form-editor', $js );
} );
