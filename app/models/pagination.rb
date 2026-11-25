# frozen_string_literal: true

# Simple offset pagination for staff lists. Out-of-range or malformed page numbers fall
# back to the nearest valid page.
class Pagination
  attr_reader :page, :per_page, :total_count

  def initialize(scope, page:, per_page: 25)
    @scope = scope
    @per_page = per_page
    @total_count = scope.count
    requested = page.to_s.match?(/\A\d{1,6}\z/) ? page.to_i : 1
    @page = requested.clamp(1, total_pages)
  end

  def records
    @records ||= @scope.limit(per_page).offset((page - 1) * per_page).to_a
  end

  def total_pages
    [ (total_count.to_f / per_page).ceil, 1 ].max
  end

  def previous_page
    page - 1 if page > 1
  end

  def next_page
    page + 1 if page < total_pages
  end

  def first_item
    total_count.zero? ? 0 : ((page - 1) * per_page) + 1
  end

  def last_item
    [ page * per_page, total_count ].min
  end

  def many_pages?
    total_pages > 1
  end
end
