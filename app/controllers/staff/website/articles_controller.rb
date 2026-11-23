# frozen_string_literal: true

module Staff
  module Website
    class ArticlesController < BaseController
      include StaffWebsiteEditorialController

      self.editorial_record_class = Article
      self.editorial_section_label = "Insights"

      before_action :set_record, except: %i[index new create]
      before_action :set_hub_meta

      private

        def set_hub_meta
          @hub_active_tab = :insights
          @hub_section_title = "Insights and articles"
          @hub_section_notice = "Articles about safety, regulation or technical standards need editorial review before publishing."
          @hub_empty_icon = :layers
          @hub_empty_title = "No articles yet"
          @hub_empty_description = "Create a draft when you have approved insight content to share."
          @hub_new_path = new_staff_website_article_path
          @hub_create_label = "New article"
        end

        def editorial_params
          permitted = params.require(:article).permit(:title, :summary, :body, :category, :seo_title, :seo_description)
          {
            title: permitted[:title],
            summary: permitted[:summary],
            body: permitted[:body],
            category: permitted[:category],
            seo: {
              "title" => permitted[:seo_title],
              "description" => permitted[:seo_description]
            }.compact
          }
        end

        def editorial_show_path(record) = staff_website_article_path(record)
        def editorial_index_path = staff_website_articles_path
    end
  end
end
