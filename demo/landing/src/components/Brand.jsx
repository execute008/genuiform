// Wordmark with the italic violet `i`. Reuse anywhere the brand appears.
export default function Brand({ className = '', as: Tag = 'span' }) {
  return (
    <Tag className={`brand ${className}`.trim()}>
      genu<span className="i">i</span>form
    </Tag>
  );
}
