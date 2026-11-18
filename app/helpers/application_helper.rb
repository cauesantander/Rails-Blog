module ApplicationHelper
  # Markdown -> HTML, sanitized again by Rails as defense in depth. A new renderer per call
  # because Redcarpet objects are not guaranteed to be thread-safe (Puma is multi-threaded).
  def markdown(text)
    # filter_html drops raw HTML written in the post; safe_links_only blocks javascript: URLs.
    renderer = Redcarpet::Render::HTML.new(filter_html: true, safe_links_only: true, hard_wrap: true)
    parser = Redcarpet::Markdown.new(renderer, autolink: true, fenced_code_blocks: true, tables: true,
                                               strikethrough: true, no_intra_emphasis: true)
    sanitize(parser.render(text.to_s))
  end

  def avatar_for(user, size: 40)
    if user.avatar.attached? && user.avatar.variable?
      image_tag user.avatar.variant(:thumb), alt: user.name, class: "avatar", width: size, height: size
    else
      tag.span(user.name.to_s.first.upcase, class: "avatar avatar--initial", style: "width:#{size}px;height:#{size}px;line-height:#{size}px")
    end
  end

  STATUS_LABELS = {
    "draft" => "Rascunho", "published" => "Publicado", "visible" => "Visível", "hidden" => "Oculto",
    "pending" => "Pendente", "confirmed" => "Confirmado", "unsubscribed" => "Cancelado",
    "scheduled" => "Agendada", "queued" => "Na fila", "sending" => "Enviando", "sent" => "Enviado",
    "canceled" => "Cancelada", "failed" => "Falhou", "skipped" => "Ignorado",
    "reader" => "Leitor", "admin" => "Administrador"
  }.freeze

  def status_badge(status)
    tag.span(STATUS_LABELS.fetch(status.to_s, status.to_s.humanize), class: "badge badge--#{status}")
  end

  def format_time(time)
    time ? l(time, format: :short) : "—"
  end
end
