# _plugins/sort_categories_by_size.rb
# Adds a Liquid filter to sort site.categories by post count (descending).
module Jekyll
  module SortCategoriesBySize
    def sort_by_post_count(categories)
      categories.sort_by { |_name, posts| -posts.size }
    end
  end
end

Liquid::Template.register_filter(Jekyll::SortCategoriesBySize)
